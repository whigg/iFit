function out = ResLibCal(varargin)
% To start the application and open the main GUI window, use
%   ResLibCal
% To compute directly the resolution function, sending an EXP ResLib-like
%   configuration structure, use:
%   out = ResLibCal(EXP);
%
% The application contains a main interface with:
% * Menu, Method, Scan and Instrument parameters (main)
% * Resolution function plot (2D)
% * Resolution function plot (3D)
%
% when changing any value in the main GUI:
% * Method and Scan parameters, Instrument parameters
% any opened view is updated after a recomputation of the resolution
%
% The 2D and 3D views can be closed without ending the application.
% When Method/Scan is closed, or Exit is selected all views are closed

% Contributions:
% ResCal5: rc_cnmat rc_popma rc_int rc_focus rc_bragg rc_bragghklz
%          rc_re2rc rc_phon
% ResLib:  ResMatS CleanArgs StandardSystem
%          modvec scalar ResMat GetLattice star GetTau
%          element sizes: the sqrt(12) has been removed everywhere. It is taken into account in modified ResMat.

% Private functions: 'out' is a full ResLibCal configuration, 'EXP' is ResLib structure
% out         = ResLibCal_Compute(EXP or out)
% resolution  = ResLibCal_ComputeResMat(EXP or out)
% fig         = ResLibCal_EXP2fig(EXP or out, fig)
% [p, labels] = ResLibCal_EXP2RescalPar(EXP or out)
% [EXP, fig]  = ResLibCal_fig2EXP(fig)
% [res, inst] = ResLibCal_FormatString(out)
% EXP         = ResLibCal_Open(filename, EXP or out) % update EXP/out from file
% EXP         = ResLibCal_RescalPar2EXP(str, EXP)
% RMS         = ResLibCal_RM2RMS(H,K,L,W,EXP,RM)
% EXP         = ResLibCal_SampleRotateS(H,K,L,EXP)
% filename    = ResLibCal_Saveas(filename, EXP)
% ResLibCal_UpdateDTau(handle)
% ResLibCal_UpdateEKLfixed(handle)
%
% Private (inline) functions:
% filename = ResLibCal_Save
% out      = ResLibCal_UpdateViews(out)
% out      = ResLibCal_ViewResolution(out, dim)
% out      = ResLibCal_UpdateResolution2(out)
% out      = ResLibCal_UpdateResolution3(out)


ResLibCal_version = [ mfilename ' 1.0 (Feb 2013) $Revision$' ];

% menu actions:
if ~isempty(varargin)
  if ishandle(varargin{1})
    varargin = [ {'update_handle'} varargin ];
  end
  
  if ischar(varargin{1})
    % check if the application window exists, else open it
%    fig=findall(0, 'Tag','ResLibCal');
%    if length(fig) > 1
%      delete(fig(2:end)); % remove duplicated windows
%      fig=fig(1);
%    end
%    if isempty(fig) || ~ishandle(fig)
%      fig = openfig('ResLibCal'); % open the main ResLibCal figure.
%      feval(mfilename, 'create'); % load last configuration
%    end
  
    action = varargin{1};
    switch lower(action)
    % menu items ---------------------------------------------------------------
    case 'file_open'
      EXP = ResLibCal_fig2EXP(get(0,'CurrentFigure'));
      if isfield(EXP,'EXP') EXP = EXP.EXP; end
      if length(varargin) < 1, varargin{2} = ''; end
      if length(varargin) < 2, varargin{3} = EXP; end
      out = ResLibCal_Open(varargin{2:end});  % (filename, EXP)
    case 'file_reset'
      filename = fullfile(prefdir, 'ResLibCal.ini');
      if ~exist(filename, 'file')
        source = 'the factory defaults.';
      else
        source = [ 'the file ' filename ' (delete it to return to factory defaults)' ];
      end
      options.Default     = 'No';
      options.Interpreter = 'tex';
      ButtonName = questdlg({ ...
        '{\fontsize{14}{\color{blue}Reload default configuration ?}}', ...
        'This will reset all fields of the ResLibCal window from ', ...
        source, ...
        '{\bf Reset now ?}'}, 'ResLibCal: Reset ?', 'Yes', 'No', options);
      if strcmp(ButtonName, 'Yes')
        if exist(filename,'file')
          feval(mfilename, 'create');
        else
          delete(fig);
          openfig('ResLibCal');
        end
      end
    case 'file_save'
      % save configuration so that it is re-opened at next re-start
      ResLibCal_Save; % (filename=prefdir)
    case 'file_saveas'
      % save configuration
      ResLibCal_Saveas(varargin{2:end}); % (filename, EXP)
    case 'file_print'
      printdlg(gcf);
    case 'file_export'
      [filename, pathname] = uiputfile( ...
         {'*.pdf',  'Portable Document Format (*.pdf)'; ...
          '*.eps',  'Encapsulated Postscript (*.eps)'; ...
          '*.png',  'Portable Network Graphics image (*.png)'; ...
          '*.jpg',  'JPEG image (*.jpg)'; ...
          '*.tif',  'TIFF image, compressed (*.tif)'; ...
          '*.bmp',  'Windows bitmap (*.bmp)'; ...
          '*.fig',  'MATLAB figure (*.fig)'; ...
          '*.*',  'All Files (*.*)'}, ...
          'Export configuration window as...');
      if isempty(filename) || all(filename == 0), return; end
      filename = fullfile(pathname, filename);
      saveas(fig, filename);
      disp([ '% Exported ' ResLibCal_version ' window to file ' filename ]);
    case 'file_exit'
      % save configuration so that it is re-opened at next re-start
      ResLibCal_Save;
      % close windows
      hObjects={'ResLibCal',...
                'ResLibCal_View2',...
                'ResLibCal_View3',...
                'ResLibCal_View1'};
      for index=1:length(hObjects)
        fig=findall(0, 'Tag',hObjects{index});
        if ishandle(fig), delete(fig); end
      end
    case 'view_resolution2'
      out = ResLibCal_ViewResolution('',2);  % open/raise View Res2
      out = ResLibCal_UpdateViews(out);
    case 'view_resolution3'
      out = ResLibCal_ViewResolution('',3);  % open/raise View Res2
      out = ResLibCal_UpdateViews(out);
    case 'view_matrix'                 % not used currently
      out = ResLibCal_ViewResolution('',1);  % open/raise View Matrix
      out = ResLibCal_UpdateViews(out);
    case 'help_content'
      link = fullfile(fileparts(which(mfilename)), 'doc', [ mfilename '.html' ]);
      disp([ mfilename ': opening help from ' link ])
      web(link);
    case 'help_about'
      % get the ILL logo from object
      cdata = get(findall(fig, 'Tag', 'ILL_logo'), 'CData');
      message = {...
        [ '{\fontsize{14}{\color{blue}' ResLibCal_version '} EUPL license} ' ], ...
        'ResLibCal is a graphical user interface to compute and display' , ...
        'the {\bf triple-axis resolution function} obtained from e.g. Copper-Nathans and Popovici analytical approximations. The GUI allows to select among a set of computation kernels.' , ...
        'This application was written by E. Farhi {\copyright}ILL/DS/CS <farhi@ill.eu> using' , ...
        '\bullet ResLib 3.4 (A. Zheludev)' , ...
        '\bullet ResCal (A. Tennant and D. Mc Morrow)' , ...
        '\bullet Res3ax (J. Ollivier)' , ...
        '\bullet vTAS view (A. Bouvet/A. Filhol)' };
      CreateMode.WindowStyle = 'modal';
      CreateMode.Interpreter='tex';
      msgbox(message, ...
        'About: ResLibCal', ...
        'custom',cdata,jet,CreateMode);
    case 'view_update'
      out = ResLibCal_Compute(varargin{2:end}); % arg can be an EXP
      ResLibCal_ViewResolution(out,2); % if not opened, open at least the 2D view
      ResLibCal_UpdateViews(out);
    case 'view_autoupdate'
      status = get(gcbo, 'Checked');
      if strcmp(status,'on'), status = 'off'; else status = 'on'; end
      set(gcbo, 'Checked', status);
    case 'view_resolutionrlu'
      status = get(gcbo, 'Checked');
      if strcmp(status,'on'), status = 'off'; else status = 'on'; end
      set(gcbo, 'Checked', status);
      ResLibCal_UpdateViews;
    % other actions (not menu items) -------------------------------------------
    case 'create'
      fig = findall(0, 'Tag','ResLibCal');
      if isempty(fig) || ~ishandle(fig)
        disp([ 'Welcome to ' ResLibCal_version ]);
        openfig('ResLibCal'); % open the main ResLibCal figure.
        filename = fullfile(prefdir, 'ResLibCal.ini');
        out = ResLibCal_Open(filename); % open the 'ResLibCal.ini' file (last saved configuration)
      elseif length(fig) > 1
        delete(fig(2:end)); % remove duplicated windows
      end
      out = ResLibCal_fig2EXP(fig);
    case 'update'
      % update all opened views with new computation (widget update)
      out = ResLibCal_Compute(varargin{2:end}); % arg can be an EXP
      if strcmp(get(findobj(gcf, 'Tag','View_AutoUpdate'), 'Checked'), 'on')
        out = ResLibCal_UpdateViews(out);
      end
    case 'update_d_tau'
      % update d-spacing from a popup item
      ResLibCal_UpdateDTau(varargin{2:end});      % arg is popup handle
    case 'update_ekl'
      % update E, K, lambda
      ResLibCal_UpdateEKLfixed(varargin{2:end});  % arg is edit box handle
    case 'update_handle'
      % handle uitable update
      if length(varargin) < 2, return; end
      h     = varargin{2};
      if strcmp(get(h,'Type'),'uitable')
        event = varargin{3};
        data  = get(h,'Data'); % NewData
        if ~isempty(event.Error) || isnan(event.NewData) 
          % revert invalid to previous data
          data(event.Indices(1),event.Indices(2)) = event.PreviousData;
          set(h,'Data',data);
        else
          out = feval(mfilename, 'update');
        end
      end
    otherwise
      try
        out = ResLibCal_Open(action, varargin{2:end});
        ResLibCal_EXP2fig(out);
        out = ResLibCal_Compute(out);
        ResLibCal_UpdateViews(out); % when they exist
      catch
        disp([ mfilename ': Unknown action ' action ]);
        out = [];
      end
    end
    % end if varargin is char
  elseif isstruct(varargin{1}) % an EXP structure ?
    ResLibCal_EXP2fig(varargin{1});
    out = ResLibCal_Compute(varargin{1});
    ResLibCal_UpdateViews(out); % when they exist
  end
  % end nargin > 0
else
  % nargin == 0
  
  % open or create the main GUI
  feval(mfilename, 'create'); % load last configuration
  out = ResLibCal_Compute;
  out = ResLibCal_UpdateViews(out); % when they exist
end
% end ResLibCal main

% ==============================================================================
% most functions in 'private'
% 

% ==============================================================================
function filename = ResLibCal_Save
  filename = ResLibCal_Saveas(fullfile(prefdir, 'ResLibCal.ini'));

% ==============================================================================
function out = ResLibCal_UpdateViews(out)
% ResLibCal_ViewResolution2: update all views (only when already visible)
%
  if nargin == 0, out = ''; end
  if ~isstruct(out), out = ResLibCal_Compute; end
  out = ResLibCal_UpdateResolution2(out); % 2D, also shows matrix
  out = ResLibCal_UpdateResolution3(out); % 3D

% ==============================================================================
function out = ResLibCal_ViewResolution(out, dim)
% ResLibCal_ViewResolution: open the Resolution 2D/3D plot view
%
  if nargin == 0, out = ''; end
  if ~isstruct(out), out = ResLibCal_Compute; end
  h = findall(0, 'Tag',[ 'ResLibCal_View' num2str(dim)]);
  if isempty(h)
    if dim~=1, name=sprintf('(%iD)', dim); else name='Matrix'; end
    h = figure('Name',[ 'ResLibCal: View Resolution ' name ], ...
               'Tag', [ 'ResLibCal_View' num2str(dim)], 'ToolBar','figure');
    p = get(h, 'Position'); p(3:4) = [ 640 480 ]; set(h, 'Position',p);
  else
    figure(h);
  end

% ==============================================================================
function out = ResLibCal_UpdateResolution2(out)
% ResLibCal_UpdateResolution2: update the 2D view
%
  if nargin == 0, out = ''; end
  if ~isstruct(out), out = ResLibCal_Compute; end
  h = findall(0, 'Tag','ResLibCal_View2');
  if isempty(h), return; end
  set(0,'CurrentFigure', h);
  
  % update/show the resolution projections
  rlu = get(findobj(out.handle,'Tag','View_ResolutionRLU'), 'Checked');
  if strcmp(rlu, 'on'), rlu='rlu'; end
  out = rc_projs(out, rlu);
  
function out = ResLibCal_UpdateResolution3(out)
% ResLibCal_UpdateResolution3: update the 3D view
%
  if nargin == 0, out = ''; end
  if ~isstruct(out), out = ResLibCal_Compute; end
  h = findall(0, 'Tag','ResLibCal_View3');
  if isempty(h), return; end
  set(0,'CurrentFigure', h);
  
  % update/show the resolution projections
  % update/show the resolution projections
  rlu = get(findobj(out.handle,'Tag','View_ResolutionRLU'), 'Checked');
  if strcmp(rlu, 'on'), rlu='rlu'; end
  out = ResPlot3D(out, rlu);

