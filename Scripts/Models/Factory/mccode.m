function y = mccode(instr, options)
% y = instrument(p) : McCode (McStas/McXtrace) instrument
%
%   iFunc/instrument a McCode instrument
%     y=monitor value for given instrument parameters
%
% MODEL CREATION:
% ------------------------------------------------------------------------------
% instrument(description)          creates a model with specified McCode instrument 
%           The instrument may be given as an '.instr' McCode description, or directly
%             as an executable.
% instrument(description, options) also specifies additional McCode options, e.g.
%           options.dir:         directory where to store results, or set automatically (string)
%           options.ncount:      number of neutron events per iteration, e.g. 1e6 (double)
%           options.mpi:         number of processors/cores to use with MPI on localhost (integer) 
%           options.machines:    filename containing the list of machines/nodes to use (string)
%           options.seed:        random number seed to use for each iteration (double)
%           options.gravitation: 0 or 1 to set gravitation handling in neutron propagation (boolean)
%           options.monitor:    a single monitor name to read, or left empty for thr last (string).
%           options.mccode:      set the executable path to 'mcrun' (default) or 'mxrun'
%
% MODEL EVALUATION:
% ------------------------------------------------------------------------------
% model(p) evaluates the model with given parameters (vector or structure). Only
%   scalar parameters of the instrument can be varied. other parameters are kept fixed.
%
% input:  p: Constant parameter (double)
%            p = [ scalar_instrument_parameters ]
%
% output: y: monitor value
% ex:     model=instrument('templateDIFF'); signal=feval(model);
%
% Version: $Date$
% See also iFunc, iFunc/fits, iFunc/plot, iFunc/feval, mcstas
% (c) E.Farhi, ILL. License: EUPL.

% check for McCode executable
persistent mccode_present

% get options
if nargin == 0
  instr = 'templateDIFF.instr';
end
if nargin > 1 && ischar(options)
    options = str2struct(options);
else
  options = struct();
end
options = instrument_parse_options(options);

% get the instrument. If not available, search for one in a McCode installation
% stop if not found
options.instrument = mccode_search_instrument(instr);

% check for McCode, only the fisrt time
if isempty(mccode_present)
  mccode_present = mccode_check(options);
end

% test if the given/found instrument is executable. Return empty if source code.
[info,exe] = instrument_get_info(options.instrument); % try --info and --help

% compile the instrument (when McCode present), possibly with MPI from options
% if no McCode executable, the user must provide an executable.
if isempty(info) && ~isempty(options.mccode)
  % compile. Stop when fails.
  result = instrument_compile(options);
  % identify and test the executable
  [info, exe] = instrument_get_info(options.instrument);
  if isempty(info)
    error([ mfilename ': Compiled instrument ' exe ' from ' options.instrument ' is not executable'])
  end
  % store the source code, and binary (executable) in UserData
  UserData.instrument_source     = fileread(options.instrument);
elseif ~isempty(info)
  % store the executable, no source code given
  UserData.instrument_source     = '';
else
  error([ mfilename ': WARNING: no information could be retrieved from ' options.instrument ]);
end
fid = fopen(exe, 'r'); 
UserData.instrument_executable = fread(fid, Inf); fclose(fid);
UserData.instrument_exe = exe;
  
[p,f,e] = fileparts(options.instrument); options.instrument = [ f e ];
[p,f,e] = fileparts(UserData.instrument_exe);        UserData.instrument_exe = [ f e ];

% get default parameters (and test executable). Store them in UserData
UserData.instrument_info    = info;
UserData.options            = options;

% identify fixed parameters (non scalar). Store them in UserData
% we search the 'Param_*' fields in info.
[UserData.Parameters, UserData.Parameters_Constant] = instrument_get_parameters(info);

y.Parameters = fieldnames(UserData.Parameters);
% set starting configuration (Guess)
c = struct2cell(UserData.Parameters);
f = fieldnames(UserData.Parameters);
y.Guess = [];
for index=1:numel(c)
  this = c{index};
  if ~isempty(this) && isfinite(this), 
       y.Guess(end+1) = this; 
  else y.Guess(end+1) = nan; end
end

disp([ mfilename ': Assembling McCode model ' options.instrument ' with ' num2str(length(y.Guess)) ' parameters.'  ]);
if ~isempty(UserData.Parameters_Constant)
  disp('  Additional parameters are stored in UserData.Parameters_Constant:')
  disp(UserData.Parameters_Constant)
end

y.Name       = strtrim([ options.instrument ' McCode [' mfilename ']' ]);
y.Description= strtrim([ 'McCode virtual experiment ' options.instrument ]);
y.UserData   = UserData;

% assemble the Expression: 
%     build target directory (put back executable if missing)
%     assemble all parameters and options (command line). Handle MPI and machine list
%     execute
%     get back results (filter monitor)
%     set signal (interp to Axes)
y.Expression = { ...
'  UD = this.UserData; options=UD.options;', ...
'  % check directory for execution', ...
'  if isempty(options.dir) || isempty(dir(options.dir))', ...
'    options.dir=tempname;', ...
'    mkdir(options.dir)', ...
'    this.UserData.options.dir = options.dir;', ...
'  end', ...
'  % check if executable is present. Write it if missing.', ...
'  if isempty(dir(fullfile(options.dir, UD.instrument_exe)))', ...
'    fid=fopen(fullfile(options.dir, UD.instrument_exe), ''w'');', ...
'    if fid==-1, error([ ''model '' this.Name '' '' this.Tag '' could not write '' fullfile(options.dir, UD.instrument_exe) ]); end', ...
'    fwrite(fid, UD.instrument_executable);', ...
'    fclose(fid); fileattrib(fullfile(options.dir, UD.instrument_exe),''+x'');', ...
'  end', ...
'  % check if source is present. Write it if missing.', ...
'  if ~isempty(UD.instrument_source) && isempty(dir(fullfile(options.dir, options.instrument)))', ...
'    fid=fopen(fullfile(options.dir, options.instrument), ''w'');', ...
'    if fid==-1, disp([ ''WARNING: model '' this.Name '' '' this.Tag '' could not write '' fullfile(options.dir, options.instrument) ]); end', ...
'    fprintf(fid, ''%s\n'', UD.instrument_source);', ...
'    fclose(fid);', ...
'  end', ...
'  % handle mpi', ...
'  if isfield(options,''mpi'') && ~isempty(options.mpi) && ...', ...
'    isnumeric(options.mpi) && options.mpi > 1', ...
'    cmd = [ ''mpirun -n '' options.mpi ];', ...
'    if isfield(options, ''machines'') && ~isempty(options.machines) && ischar(options.machines)', ...
'      cmd = [ cmd '' -machinefile '' options.machines ];', ...
'    end', ...
'  else cmd = ''''; end', ...
'  % assemble command line', ...
'  if ~isempty(dir(fullfile(options.dir,''sim'')))', ...
'    rmdir(fullfile(options.dir,''sim''),''s''); end', ...
'  cmd = [ cmd fullfile(options.dir, UD.instrument_exe) '' --ncount='' num2str(options.ncount) ...', ...
'    '' --dir='' fullfile(options.dir,''sim'') ];', ...
'  f = this.Parameters;', ...
'  for index=1:numel(f) % variable instrument parameters', ...
'    cmd = [ cmd '' '' f{index} ''='' num2str(p(index)) ];', ...
'  end', ...
'  f = fieldnames(UD.Parameters_Constant);', ...
'  for index=1:numel(f) % constant (other) instrument parameters', ...
'    p0 = UD.Parameters_Constant.(f{index});', ...
'    if isempty(p), continue; end', ...
'    if isnumeric(p0)', ...
'      cmd = [ cmd '' '' f{index} ''='' num2str(p0) ];', ...
'    elseif ischar(p0)', ...
'      cmd = [ cmd '' '' f{index} ''="'' p0 ''"'' ];', ...
'    end', ...
'  end', ...
'  % execute', ...
'  disp(cmd);', ...
'  [status, result] = system(cmd);', ...
'  disp(result)', ...
'  if status', ...
'    error([ ''Model '' this.Name '' '' this.Tag '' failed to execute '' cmd ]);', ...
'  end', ...
'  % read results', ...
'  signal = [];', ...
'  if ~isempty(options.monitor) && ischar(options.monitor)', ...
'    signal = iData(fullfile(options.dir,''sim'',[ strtrim(options.monitor) ''*'' ]));', ...
'  end', ...
'  if isempty(signal), signal = iData(fullfile(options.dir,''sim'',''mccode.sim'')); end', ...
'' ...
};

y.ParameterValues = y.Guess;

% create the iFunc model
y = iFunc(y);

% evaluate the model to get its monitors, and derive the dimensionality
% all parameters must be defined to get execute with default values
if ~any(isnan((y.Guess)))
  disp([ mfilename ': Determining the model dimension... (please be patient)' ]);
  signal = feval(y,y.Guess);
  if numel(signal) > 1
    % get the monitor Positions, and the further away one
    positions = get(signal,findfield(signal, 'position'));
    if ~isempty(positions)
      [~,index_position] = max(cellfun(@(c)norm(c), positions));
    else
      index_position = numel(signal); % last one
    end
    signal=signal(index_position);
  end
  disp(signal); % this is an iData object
  y.UserData.options.monitor = get(signal,'Component');
  y.Dimension = ndims(signal);
  % handle interpolation onto axes
  ax = ',x,y,z,t';
  y.Expression{end+1} = 'if length(signal) > 1, signal = signal(end); end';
  y.Expression{end+1} = [ 'if ~isempty(x), signal = interp(signal ' ax(1:(2*y.Dimension)) '); end;' ];
  y.Expression{end+1} = 'signal = double(signal);';
  % update model description
  y.Description = [ y.Description ...
    sprintf('\n  Using monitor %s', y.UserData.options.monitor) ];
  for index=1:y.Dimension
    x = getaxis(signal, index); x=x(:);
    y.Description = [ y.Description ...
      sprintf('\n  Axis %i "%s" label is "%s", range [%g:%g]', index, ax(2*index), label(signal, index), min(x), max(x)) ];
  end
end




% ==============================================================================
function options = instrument_parse_options(options)
  if ~isfield(options,'instrument'), options.instrument = ''; end
  if ~isfield(options,'ncount'),     options.ncount     = 1e6; end
  if ~isfield(options,'mccode'),     options.mccode     = 'mcrun'; end
  if ~isfield(options,'dir'),        options.dir        = ''; end
  if ~isfield(options,'monitor'),    options.monitor    = ''; end
  if ~isfield(options,'gravitation'),options.gravitation= 0; end
  
% ------------------------------------------------------------------------------
function present = mccode_check(options)
% check if McCode (mcstas or mcxtrace) is present
  present = '';
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ;';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ; '; 
  else           precmd = ''; end
  
  for totest = { options.mccode, 'mcrun','mxrun' }
    for ext={'','.pl','.py','.exe','.out'}
      % look for executable and test with various extensions
      [status, result] = system([ precmd totest{1} ext{1} ]);
      if (status == 1 || status == 255) 
        present = options.mccode;
        return
      end
    end
  end
  
  if isempty(present)
    disp([ mfilename ': WARNING: ' options.mccode ' McStas/McXtrace executable is not installed. Get it at www.mccode.org' ]);
    disp('  The model can still be created if the instrument is given as an executable.')
  end

% ------------------------------------------------------------------------------
function instr = mccode_search_instrument(instr)

  % get/search instrument
  % check if the instrument exists, else attempt to find it
  if ~isempty(instr)
    index = dir(instr);
  else return;
  end
  
  if ~isempty(index), return; end % given file is fully qualified
  
  for ext={'','.instr','.out','.exe'}
    out = [ instr ext{1} ];
    % check for instrument in McStas/McXtrace libraries
    search_dir = { getenv('MCSTAS'), getenv('MCXTRACE'), ...
      '/usr/local/lib/mc*', 'C:\mc*', '/usr/share/mcstas/'};
    if isempty(index)
      % search the instrument recursively in all existing directories in this list
      index = getAllFiles(search_dir, out);
      if ~isempty(index)
        disp([ mfilename ': Using instrument ' index ] );
        instr = index;
        return
      end
    end
  end
  
  if isempty(index)
    error([ mfilename ': ERROR: Can not find instrument ' instr ]);
  end
  
% ------------------------------------------------------------------------------
% function to search for a file recursively
function fileList = getAllFiles(dirName, File)

  % allow search in many directories
  if iscell(dirName)
    for d=1:length(dirName)
      fileList=getAllFiles(dirName{d}, File);
      if ~isempty(fileList)
        break
      end
    end
    return
  end
  
  dirData = dir(dirName);                 % Get the data for the current directory
  fileList= [];
  if ~isdir(dirName), dirName = fileparts(dirName); end
  if isempty(dirData), return; end
  dirIndex = [dirData.isdir];             % Find the index for directories
  fileList = {dirData(~dirIndex).name}';  % Get a list of the files
  if ~isempty(fileList)
    index = find(strcmp(File, fileList));
    if ~isempty(index)
      fileList = fullfile(dirName,fileList{index(1)});  % get the full path/file name
      return
    else
      fileList = [];
    end
  end
  subDirs = {dirData(dirIndex).name};          % Get a list of the subdirectories
  validIndex = ~ismember(subDirs,{'.','..'});  % Find index of subdirectories
                                               %   that are not '.' or '..'
  
  for iDir = find(validIndex)                  % Loop over valid subdirectories
    nextDir = fullfile(dirName,subDirs{iDir}); % Get the subdirectory path
    fileList = getAllFiles(nextDir, File);     % Recursively call getAllFiles
    if ~isempty(fileList), return; end
  end

% ------------------------------------------------------------------------------
function [info, exe] = instrument_get_info(executable)
  % calls the instrument with --info or --help to attempt to get information
  % parse the output and return a structure.
  
  info = ''; exe = '';
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ;';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ; '; 
  else           precmd = ''; end
  
  [p,f,e] = fileparts(executable);
  
  for name={executable, fullfile(p,f), f, [ f e ], fullfile('.',f), fullfile('.',[ f e])}
    for ext={'','.out','.exe'}
      for opt={' --info',' --help',' -h'}
        % look for executable and test with various extensions
        exe = [ name{1} ext{1} ];
        [status, result] = system([ precmd exe opt{1} ]);
        if (status == 0 || status == 255) 
          info = result;
          return
        end
      end
    end
  end

% ------------------------------------------------------------------------------
function result = instrument_compile(options)

  % compile the instrument using McCode
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ;';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ; '; 
  else           precmd = ''; end
  
  disp([ mfilename ': Compiling instrument from ' options.instrument ...
    ' using ' options.mccode]);
  % assemble the command line: compile, no particle generated
  cmd = [ options.mccode ' --force-compile ' options.instrument ' --ncount=0' ];  
  if isfield(options,'mpi')
    cmd = [ cmd ' --mpi=1' ]
  end
  disp(cmd)
  [status, result] = system([ precmd cmd ]);
  % stop if compilation fails...
  if (status ~= 0 && status ~= 255) 
    disp(result);
    error([ mfilename ': ERROR: failed compilation of ' options.instrument ]);
  end  
  
% ------------------------------------------------------------------------------
function [dynamic, static] = instrument_get_parameters(info)
  % analyze the --help or --info string and search for parameters with default values
  
  % we search
  % line  'Parameters: par1(type) par2(type) ...
  % lines 'Param: <name>=<val>  only for parameters which have default values
  % lines 'par (type)'
  % lines 'par (type) [default='val']'
  %
  % 'type' can be: double, string, int
  
  if isempty(info), return; end
  info = textscan(info, '%s','Delimiter','\n\r');
  info = info{1};
  
  dynamic = struct();
  static  = struct();
  
  % will set flag to true when we start to scan 'Instrument parameters'
  flag_instr_pars = false;  
  
  % now we scan lines
  for l_index = 1:numel(info)
    this_line = strtrim(info{l_index});
    if strncmpi(this_line, 'Parameters:', length('Parameters:'))
      this_line = strtrim(this_line(length('Parameters: '):end));
      % regular expression to search for par(type)
      % store all these parameter names: double as variable, others as static
      % default value is set to []
      par=regexp(this_line,'(\w+)\s*\(double\)',    'tokens');
      for index=1:numel(par)
          name = par{index};
          if ~isempty(name), dynamic.(name{end}) = []; end
      end
      par=regexp(this_line,'(\w*)\s*\((string|int)\)','tokens');
      for index=1:numel(par)
          name = par{index};
          if ~isempty(name), static.(name{1}) = []; end
      end
      
    elseif strncmpi(this_line, 'Param:', length('Param:'))
      par = str2struct(this_line); c={}; f={};
      while isstruct(par)
        c = struct2cell(par); % get the content
        f = fieldnames(par);
        if isstruct(c{end}), par = c{end};
        else par = c; end
      end
      % assign the parameter depending on its type
      if ~isempty(c)
        if   isnumeric(c{end}), dynamic.(f{end}) = c{end};
        else                    static.(f{end})  = c{end}; end
      end
    elseif strncmpi(this_line, 'Instrument parameters', length('Instrument parameters'))
      flag_instr_pars = true;
    elseif flag_instr_pars
      % search for parameter with default value
      par=regexp(this_line,'(\w)+\s*\((double|string|int)\)\s*\[default=''(.*)''\]','tokens');
      if ~isempty(par)
          % tok has 3 elements: name, type, value
          for index=1:numel(par)
            var = par{index};
            name = var{1};
            val  = var{3};
            if ~isempty(str2num(val)), val = str2num(val); end
            if strcmp(var{2},'double'), dynamic.(name) = val;
            else                 static.(name)  = val; end
          end
          continue
      end
      % search for parameter without default value
      par=regexp(this_line,'(\w)+\s*\((double|string|int)\)','tokens');
      % tok has 2 elements: name, type
      for index=1:numel(par)
        var = par{index};
        name = var{1};
        if strcmp(var{2},'double'), dynamic.(name) = [];
        else                 static.(name)  = []; end
      end
    end
  end
