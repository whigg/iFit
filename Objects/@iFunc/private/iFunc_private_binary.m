function c = iFunc_private_binary(a, b, op, varargin)
% iFunc_private_binary: handles binary operations
%
% Operator may apply on an iFunc array and:
%   a scalar/vector/matrix
%   a single iFunc object, which is then used for each iFunc array element
%     operator(a(index), b)
%   a string which is catenated with the Expression
%   an iFunc array, which should then have the same dimension as the other 
%     iFunc argument, in which case operator applies on pairs of both arguments.
%     operator(a(index), b(index))
%   an iData object (2nd arg), which is inserted into the evaluation code (stored in UserData and evaluated on current axes)
%
% operator may be: 'plus','minus','times','rdivide','conv', 'xcorr', 'power'
%                  'mtimes','mrdivide','mpower' -> perform orthogonal axes dimensionality extension

% supported syntax: 
% iFunc <op> iFunc -> catenate Parameters Constraint and Expression, rename p and signal for each iFunc
% iFunc <op> scalar
% iFunc <op> string -> directly catenate with the Expression
% iFunc <op> global variable (caller/base)
% iFunc <op> iData  -> interpolate iData on iFunc current axes at evaluation

% handle iFunc array input
if isa(a,'iFunc') && numel(a) > 1
  c = [];
  for index=1:numel(a)
    c = [ c iFunc_private_binary(a(index), b, op, varargin{:}) ];
  end
  return
elseif isa(b,'iFunc') && numel(b) > 1
  c = [];
  for index=1:numel(b)
    c = [ c iFunc_private_binary(a, b(index), op, varargin{:}) ];
  end
  return
end

isFa = isa(a, 'iFunc');
isFb = isa(b, 'iFunc');
if isempty(varargin)
  v = '';
else
  v = [ ', ''' char(varargin{1}) '''' ];
end

if ~isFa && ischar(a) && isvarname(a)
  a = constant(a);
  isFa = 1;
end
if ~isFb && ischar(b) && isvarname(b)
  b = constant(b);
  isFb = 1;
end

% make sure we have chars only (get rid of function handles)
if isFa 
  ax = 'x,y,z,t,u,v,w,'; ax = ax(1:(a.Dimension*2));
  if isa(a.Expression, 'function_handle')
    a.Expression = { sprintf('signal = feval(%s, p, %s);', func2str(a.Expression), ax(1:(end-1))) };
  end
  if ~isstruct(a.Constraint)
      a.Constraint.eval=[];
      a.Constraint.fixed = [];
      a.Constraint.min = [];
      a.Constraint.max = [];
      a.Constraint.set = [];
  end
  if ~iscellstr(a.Expression), a.Expression = cellstr(a.Expression); end
  if isa(a.Constraint.eval, 'function_handle')
    a.Constraint.eval = sprintf('p = feval(%s, p, %s);', func2str(a.Constraint.eval), ax(1:(end-1)));
  end
  if isa(a.Guess, 'function_handle')
    a.Guess = sprintf('[ feval(%s, %s, signal) ]', func2str(a.Guess), ax(1:(end-1)));
  elseif isnumeric(a.Guess)
    a.Guess = num2str(a.Guess(:)');
  elseif isempty(a.Guess)
    a.Guess = NaN*ones(length(a.Parameters),1);
  end
end

if isFb
  ax = 'x,y,z,t,u,'; ax = ax(1:(b.Dimension*2));
  if isa(b.Expression, 'function_handle')
    b.Expression = { sprintf('signal = feval(%s, p, %s);', func2str(b.Expression), ax(1:(end-1))) };
  end
  if ~isstruct(b.Constraint)
      b.Constraint.eval=[];
      b.Constraint.fixed = [];
      b.Constraint.min = [];
      b.Constraint.max = [];
      b.Constraint.set = [];
  end
  if ~iscellstr(b.Expression), b.Expression = cellstr(b.Expression); end
  if isa(b.Constraint.eval, 'function_handle')
    b.Constraint.eval = { sprintf('p = feval(%s, p, %s);', func2str(b.Constraint.eval), ax(1:(end-1))) };
  end
  if isa(b.Guess, 'function_handle')
    b.Guess = sprintf('[ feval(%s, %s, signal) ]', func2str(b.Guess), ax(1:(end-1)));
  elseif isnumeric(b.Guess)
    b.Guess = num2str(b.Guess(:)');
  elseif isempty(b.Guess)
    b.Guess = NaN*ones(length(b.Parameters),1);
  end
end

if isFa, c=a; else c=b; end

% now handle single object operation
if isFa && isFb
  % check Dimension: must be identical
  if a.Dimension ~= b.Dimension && 0
    error(['iFunc:' mfilename ], [mfilename ': can not apply operator ' op ' between iFunc objects of different dimensions' num2str(a.Dimension) ' and ' num2str(b.Dimension) '.' ]);
  end

  % use Tag-based names to copy/store signal and parameters
  tmp_a=a.Tag; 
  tmp_b=b.Tag; 
  if strcmp(tmp_a, tmp_b)
    t=iFunc;
    tmp_b=t.Tag;
  end
  % determine parameter indices for each object
  i1a=    1; i2a=    length(a.Parameters);
  i1b=i2a+1; i2b=i2a+length(b.Parameters);
  
  % append Parameter names
  Parameters(i1a:i2a)=a.Parameters;
  Parameters(i1b:i2b)=b.Parameters;
  % check for unicity of names and possibly rename similar ones
  [Pars_uniq, i,j] = unique(strtok(Parameters)); % length(j)=Pars_uniq, length(i)=Parameters
  for index=1:length(Pars_uniq)
    index_same=find(strcmp(Pars_uniq(index), strtok(Parameters)));
    if length(index_same) > 1 % more than one parameter with same name
      for k=2:length(index_same)
        [tok,rem] = strtok(Parameters{index_same(k)});
        % check if parameter name is already a renamed one with '_<number>'
        j = regexp(tok, '_[0-9]+$', 'match');
        if ~isempty(j)
          j = j{1};                       % the new incremented parameter duplicate
          j = str2num(j(2:end))+length(index_same)-1; 
          tok((end-length(j)):end) = '';  % the root of the name
        else
          j = k;
        end
        Parameters{index_same(k)} = [ tok '_' num2str(j) ' ' rem ];
      end
    end
  end
  c.Parameters=Parameters; clear Parameters

  % append parameter Guess
  if ischar(a.Guess) && isnumeric(b.Guess)
    b.Guess = mat2str(b.Guess(:)');
  elseif ischar(b.Guess) && isnumeric(a.Guess)
    a.Guess = mat2str(a.Guess(:)');
  end
  if ischar(a.Guess) && ischar(b.Guess)
    Guess = [ '[ ' a.Guess ' ' b.Guess ']' ];
  elseif isnumeric(a.Guess) && isnumeric(b.Guess) && ...
         length(a.Guess) == length(a.Parameters) && ...
         length(b.Guess) == length(b.Parameters)
    Guess = NaN*ones(length(a.Parameters)+length(b.Parameters), 1);
    if length(a.Guess)==length(i1a:i2a), Guess(i1a:i2a)=a.Guess(:); end
    if length(b.Guess)==length(i1b:i2b), Guess(i1b:i2b)=b.Guess(:); end
  else
    Guess=[];
  end

  c.Guess=Guess; clear Guess
  
  % store UserData
  c.UserData.(tmp_a)=a.UserData;
  c.UserData.(tmp_b)=b.UserData;
  
  % handle cross/orthogonal axes operation -> extend dimension
  if any(strcmp(op, {'mpower','mtimes','mrdivide'}))
    c.Dimension=a.Dimension + b.Dimension;
  else
    c.Dimension=max(a.Dimension,b.Dimension);
  end
  
  % set expressions to store, set and reset parameters/UserData/axes
  ax = 'x,y,z,t,u,v,w,'; ax = ax(1:(c.Dimension*2-1));
  string.head = [ ...
    sprintf('%s_p          = p(%i:%i); %% store 1st object parameters\n', tmp_a, i1a, i2a), ...
    sprintf('%s_p          = p(%i:%i); %% store 2nd object parameters\n', tmp_b, i1b, i2b), ...
    sprintf('%s_UserData   = this.UserData.%s; %% store 1st object UserData\n', tmp_a, tmp_a), ...
    sprintf('%s_UserData   = this.UserData.%s; %% store 2nd object UserData\n', tmp_b, tmp_b), ...
    sprintf('p             = %s_p; %% get 1st object parameters\n', tmp_a), ...
    sprintf('this.UserData = %s_UserData; %% get 1st object UserData\n', tmp_a), ...
    sprintf('%s_ax         = { %s }; %% store the initial axes\n', tmp_a, ax);
  ];
  
  % switch between models: restore parameter values, UserData, axes
  string.core = [ ...
    sprintf('%s_p          = p; %% update 1st object parameters\n', tmp_a), ...
    sprintf('%s_UserData   = this.UserData; %% update 1st object UserData\n', tmp_a), ...
    sprintf('p             = %s_p; %% get 2nd object parameters\n', tmp_b), ...
    sprintf('this.UserData = %s_UserData; %% get 2nd object UserData\n', tmp_b), ...
    sprintf('[%s]          = deal(%s_ax{:}); %% restore the initial axes\n', ax, tmp_a);
  ];
  
  string.tail = [ ...
    sprintf('%s_p          = p; %% update 2nd object parameters\n', tmp_b), ...
    sprintf('%s_UserData   = this.UserData; %% update 2nd object UserData\n', tmp_b), ...
    sprintf('p = [ %s_p(:) ; %s_p(:) ]; %% upgrade whole parameters\n', tmp_a, tmp_b), ...
    sprintf('this.UserData.%s = %s_UserData;\n', tmp_a, tmp_a), ...
    sprintf('this.UserData.%s = %s_UserData;\n', tmp_b, tmp_b), ...
  ];
  
  % append Description and Name
  if isempty(a.Description), a.Description = sprintf('%iD', ndims(a)); end
  if isempty(b.Description), b.Description = sprintf('%iD', ndims(b)); end
  c.Description = [ '(', a.Description, ') ', op, ' (', b.Description, ')' ]; 
  
  if isempty(a.Name), a.Name = tmp_a; end
  if isempty(b.Name), b.Name = tmp_b; end
  c.Name        = [ '(', a.Name, ') '       , op, ' (', b.Name, ')' ]; 
  
  % new Tag and Date
  t = iFunc;
  c.Tag  = t.Tag;
  c.Date = t.Date;
  
  % append Constraint ==========================================================
  if     isempty(a.Constraint.eval), 
      c.Constraint.eval = b.Constraint.eval;
  elseif isempty(b.Constraint.eval), 
      c.Constraint.eval = a.Constraint.eval;
  else
    % append Constraint: 1st
    c.Constraint.eval = [ ...
      string.head, ...
      a.Constraint.eval, ...
      string.core ];
      
    % handle dimensionality expansion (orthogonal)
    if any(strcmp(op, {'mpower','mtimes','mrdivide'}))
      ax = 'xyztuvw';
      % store inital axes definitions
      for index=1:c.Dimension
        c.Constraint.eval = [ c.Constraint.eval, sprintf('%s_%s = %s; %% store initial axes\n', tmp_a, ax(index), ax(index)) ];
      end
      % set 'b' axes from input axes, shifted backwards
      for index=1:b.Dimension
        c.Constraint.eval = [ c.Constraint.eval, sprintf('%s = %s; %% axes for 2nd object\n', ax(index), ax(index+a.Dimension)) ];
      end
    end
    
    % append Constraint: 2nd
    c.Constraint.eval = [ c.Constraint.eval, ...
      b.Constraint.eval, ...
      string.tail ];
    % restore initial axes definitions
    if any(strcmp(op, {'mpower','mtimes','mrdivide'}))
      for index=1:c.Dimension
        c.Constraint.eval = [ c.Constraint.eval, sprintf('%s = %s_%s; %% restore initial axes\n', ax(index), tmp_a, ax(index)) ];
      end
    end
  end
  
  % append Constraint.fixed, min, max, set
  if isFa && isFb
    c.Constraint.fixed = [ a.Constraint.fixed ; b.Constraint.fixed ];
    c.Constraint.min   = [ a.Constraint.min   ; b.Constraint.min ];
    c.Constraint.max   = [ a.Constraint.max   ; b.Constraint.max ];
    c.Constraint.set   = [ a.Constraint.set   ; b.Constraint.set ];
  end
  
  % append ParameterValues
  if isFa && isFb
    if isempty(a.ParameterValues) && ~isempty(b.ParameterValues)
      a.ParameterValues = NaN*ones(length(a.Parameters),1); 
    elseif isempty(b.ParameterValues) && ~isempty(a.ParameterValues) 
      b.ParameterValues = NaN*ones(length(b.Parameters),1);
    end
    if length(a.ParameterValues) == length(a.Parameters) && length(b.ParameterValues) == length(b.Parameters)
      c.ParameterValues = [ a.ParameterValues(:) ; b.ParameterValues(:) ];
    end
  end
  
  % append Guess ==========================================================
  if isempty(c.Guess) && ~isempty(a.Guess) && ~isempty(b.Guess)
    % append Guess: 1st
    if strncmp(strtrim(a.Guess(1:2)),'p=',2) % 'a' is already the result of a binary operation
      c.Guess = [ ...
        string.head, ...
        sprintf('%s; %% evaluate 1st guess for %s\n', a.Guess, op), ...
      ];
    else
      c.Guess = [ ...
        string.head, ...
        sprintf('p=%s; %% evaluate 1st guess for %s\n', a.Guess, op), ...
      ];
    end
    % handle dimensionality expansion (orthogonal)
    if any(strcmp(op, {'mpower','mtimes','mrdivide'}))
      ax = 'xyztuvw';
      % store inital axes definitions
      for index=1:c.Dimension
        c.Guess = [ c.Guess, sprintf('%s_%s = %s; %% store initial axes\n', tmp_a, ax(index), ax(index)) ];
      end
      % set 'b' axes from input axes, shifted backwards
      for index=1:b.Dimension
        c.Guess = [ c.Guess, sprintf('%s = %s; %% axes for 2nd object\n', ax(index), ax(index+a.Dimension)) ];
      end
    end
    
    % append Guess: 2nd
    if strncmp(b.Guess(1:2),'p=',2) % 'b' is already the result of a binary operation
      c.Guess = [ c.Guess, ...
        string.core, ...
        sprintf('%s; %% evaluate 2nd Guess for %s\n', b.Guess, op), ...
        string.tail ];
    else
      c.Guess = [ c.Guess, ...
        sprintf('p=%s; %% evaluate 2nd Guess for %s\n', b.Guess, op), ...
        string.tail ];
    end
  end
  
  % append Expression:
  % =========================================================
  %  and store 'p' and UserData for each object
  
  c.Expression = { ...
    string.head, ...
    a.Expression{:}, ...
    sprintf('\n%s_s = signal;\n', tmp_a) };
  
  % handle dimensionality expansion (orthogonal)
  if any(strcmp(op, {'mpower','mtimes','mrdivide'}))
    ax = 'xyztuvw';
    % store inital axes definitions
    for index=1:c.Dimension
      c.Expression{end+1} = sprintf('%s_%s = %s; %% store initial axes\n', tmp_a, ax(index), ax(index));
    end
    % set 'b' axes from input axes, shifted backwards
    for index=1:b.Dimension
      c.Expression{end+1} = sprintf('%s = %s; %% axes for 2nd object\n', ax(index), ax(index+a.Dimension));
    end
  end
  
  % append Expression: 2nd  
  c.Expression = { c.Expression{:}, ...
    string.core, ...
    b.Expression{:}, ...
    string.tail };
  if any(strcmp(op, {'mpower','mtimes','mrdivide'}))
    % orthogonal operation
    c.Expression{end+1} = sprintf('signal=bsxfun(@%s, %s_s, signal); %% operation: %s (orthogonal axes)\n', op(2:end), tmp_a, op);
  else
    c.Expression{end+1} = sprintf('signal=feval(@%s, %s_s, signal%s); %% operation: %s\n', op, tmp_a, v, op); % with additional parameters
  end

elseif isFa && ischar(b)  % syntax: iFunc+'string'
  c.Expression = cellstr(c.Expression);
  if strcmp(op, 'plus') && ~isempty(find(b == '=' | b == ';'))
    c.Expression{end+1} = sprintf('\n%s%s;', b, v) ;
  else
    c.Expression{end+1} = sprintf('\nsignal=%s(signal,%s%s);', op, b, v);
  end
  c.Name       = sprintf('%s(%s,%s)', op, c.Name, b(1:min(10,length(b))));
elseif isFb && ischar(a)  % syntax: 'string'+iFunc
  c.Expression = cellstr(c.Expression);
  if strcmp(op, 'plus') && ~isempty(find(a == '=' | a == ';'))
    c.Expression = { sprintf('%s%s;\n', a, v), c.Expression{:} } ;
  else
    c.Expression{end+1} = sprintf('\nsignal=%s(%s,signal%s);', op, a, v);
  end
  c.Name       = sprintf('%s(%s,%s)', op, a(1:min(10,length(a))), c.Name);
elseif isFa && ~isa(b, 'iData') && isnumeric(b) % syntax: iFunc+array
  c.Expression = cellstr(c.Expression);
  % special case for mpower iFunc^n -> dimension extension
  if strcmp(op, 'mpower') && b == floor(b) && b>1
    for index=1:(b-1)
      c = c*a;
    end
  else
    b = mat2str(double(b)); 
    c.Expression{end+1} = sprintf('\nsignal=%s(signal,%s%s);', op, b, v);
    if length(b) > 13, b=[ b(1:10) '...' ]; end
  end
  c.Name       = sprintf('%s(%s,%g)', op, c.Name, b);
elseif isFb && ~isa(a, 'iData') && isnumeric(a) % syntax: array+iFunc
  c.Expression = cellstr(c.Expression);
  a = mat2str(double(a));
  c.Expression{end+1} = sprintf('\nsignal=%s(%s,signal%s);', op, a, v);
  if length(a) > 13, a=[ a(1:10) '...' ]; end
  c.Name       = sprintf('%s(%s,%g)', op, c.Name, a);
elseif isFa && isa(b, 'iData')  % syntax: iFunc+iData
  % we store the iData object, and must interpolate on axes at eval
  c.Expression = cellstr(c.Expression);
  if isempty(c.UserData) || isstruct(c.UserData)
    ud.User = c.UserData;
  end
  ud.([ 'iData_' b.Tag ]) = b;
  c.UserData = ud;
  ax = 'x,y,z,t,u,v,w,'; ax = ax(1:(a.Dimension*2-1));
  c.Expression{end+1} = ...
    sprintf('\nsignal=%s(signal,double(interp(this.UserData.iData_%s, %s))%s);', ...
    op, b.Tag, ax, v);
    
elseif isFb && isa(a, 'iData')  % syntax: iData+iFunc
  % we store the iData object, and must interpolate on axes at eval
  c.Expression = cellstr(c.Expression);
  if isempty(c.UserData) || isstruct(c.UserData)
    ud.User = c.UserData;
  end
  ud.([ 'iData_' a.Tag ]) = a;
  c.UserData = ud;
  ax = 'x,y,z,t,u,v,w,'; ax = ax(1:(b.Dimension*2-1));
  c.Expression{end+1} = ...
    sprintf('\nsignal=%s(double(interp(this.UserData.iData_%s, %s)),signal%s);', ...
    op, a.Tag, ax, v);
else
  error(['iFunc:' mfilename ], [mfilename ': can not apply operator ' op ' between class ' class(a) ' and class ' ...
      class(b) '.' ]);
end

c.Eval=cellstr(c); % trigger new Eval


