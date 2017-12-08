function s = Sqw_check(s)
% Sqw_check: check if a 2D iData is a S(q,w).
%
% This routine can also convert automatically an input 
%         S(phi,t)  into S(phi,w)
%   and   S(phi,w)  into S(q,  w).
%
% conventions:
% omega = Ei-Ef = energy lost by the neutron
%    omega > 0, neutron looses energy, can not be higher than Ei (Stokes)
%    omega < 0, neutron gains energy, anti-Stokes
%
% input:
%   s: Sqw data set
%        e.g. 2D data set with w as 1st axis (rows), q as 2nd axis.
%
% Example: sqw=Sqw_check('SQW_coh_lGe.nc');
% (c) E.Farhi, ILL. License: EUPL.

  if nargin == 0, return; end
  
  if ~isa(s, 'iData'), s=iData(s); end
  
  % handle array of objects
  if numel(s) > 1
    sqw = [];
    for index=1:numel(s)
      sqw = [ sqw feval(mfilename, s(index)) ];
    end
    s(index)=iData; % free memory
    s = sqw;
    return
  end
  
  if isempty(s), return; end
  
  % check if the data set is Sqw (2D)
  w_present=0;
  q_present=0;
  a_present=0;
  t_present=0;
  alpha_present=0;
  beta_present=0;
  if isa(s, 'iData') && ndims(s) == 2
    for index=1:2
      lab = lower(label(s,index));
      def = getaxis(s, num2str(index));
      if ischar(def), lab = [ def ' ' lab ]; end
      if isempty(lab), lab=lower(getaxis(s, num2str(index))); end
      lab = strread(lab, '%s'); % split string into cell
      if strcmpm(lab, {'alpha','a'}) % strcmpm = multiple strcmpi is private below
        alpha_present=index;
      elseif strcmpm(lab, {'beta','b'})
        beta_present=index;
      elseif strcmpm(lab, {'wavevector','momentum','q','k','angs'})
        q_present=index;
      elseif strcmpm(lab, {'energy','frequency','w','e','mev'})
        w_present=index;
      elseif strcmpm(lab, {'time','sec','t','tof'})
        t_present=index;
      elseif strcmpm(lab, {'angle','deg','theta','phi'})
        a_present=index;
      end
    end
  end

  % conversions
  if alpha_present && beta_present && (~w_present || ~q_present)
    s = Sab_Sqw(s); % convert from S(alpha,beta) to S(q,w)
    return
  end
  
  % search for Sqw parameters for further conversions
  if ~isfield(s, 'parameters')
    s = Sqw_parameters(s);
  end
  if ~w_present && t_present
    % convert from S(xx,t) to S(xx,w): t2e requires L2=Distance
    s = Sqw_t2e(s);
    s = Sqw_check(s);
    return
  end
  if ~q_present && a_present && w_present
    % convert from S(phi,w) to S(q,w)
    s = Sqw_phi2q(s);
    s = Sqw_check(s);
    return
  end
  if ~w_present || ~q_present
    disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ]);
    disp('    does not seem to be an isotropic S(|q|,w) 2D object. Ignoring.');
    s = [];
    return
  end

  % check if we need to transpose the S(q,w)
  if w_present==2 && q_present==1
    s = transpose(s);
  end
  
  % this is the weighting for valid data
  s(~isfinite(s)) = 0;
  
  % check 'classical' and 'symmetric'
  if isfield(s,'classical') 
    classical0 = s.classical;
  else
    classical0 = [];
  end
  
  w  = s{1};
  % checks that we have 0<w<Ei for Stokes, and w<0 can be lower (anti-Stokes)
  if any(w(:) < 0) && any(w(:) > 0)
    % for experimental data we should get w1=max(w) < Ei and w2 can be as low as
    % measured (neutron gains energy from sample).
    
    
    w1 = max(w(:)); w2 = max(-w(:)); % should have w1 < w2
    if w1 > w2*2
      % we assume the measurement range is at least [-2*Ei:Ei]
      disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ]);
      disp('    indicates that the energy range is mostly in the positive side.')
      disp('    Check that it corresponds with the neutron loss/sample gain Stokes side');
      disp('    and if not, revert energy axis with e.g. setaxis(s, 1, -s{1})');
    end
  end

  % can we guess if this is classical data ? get temperature ?
  w = s{1};

  if any(w(:) < 0) && any(w(:) > 0)
    % restrict the energy axis to the common +/- range
    w1 = max(w(:)); w2 = max(-w(:)); w_max = min([w1 w2]);

    if w1 ~= w_max || w2 ~= w_max
      s_res  = ylim(s, [-w_max w_max]); % restricted to [-w:w] range
    else
      s_res = s;
    end
    % get axes
    w = s_res{1};
    
    % we compare the s(q,w) and s(q,-w)
    s_opp = setaxis(s_res, 1, -w);
    s_opp = sum(s_opp,2); s_opp = sort(s_opp, 1);

    s_res = sum(s_res,2); s_res = sort(s_res, 1);

    % the ratio should be S(q,w)/S(q,-w) = exp(hw/kT)
    % so log(S(q,w)) - log(S(q,-w)) = hw/kT
    log_s_ratio = log(s_res) - log(s_opp);
    w = log_s_ratio{1};
    clear s_res s_opp
    
    % mean_log_ratio = mean(log_s_ratio,0);
    % std_log_ratio  = std(log_s_ratio,0);
    
    % compute the temperature from the Data
    % log_s_ratio should be a constant if S(q,w) contains Bose
    % then kT = w./log_s_ratio
    T         = w./log_s_ratio*11.6045; % 1 meV = 11.6045 K
    T         = T{0};
    if any(isfinite(T)) && (all(T(~isnan(T))>0.1) || all(T(~isnan(T))<0.1))
      T         = mean(real(T(~isnan(T))));
    else T=NaN;
    end

    if isfinite(T) && T < -0.1
      disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ]);
      disp([ '    indicates a negative temperature T=' num2str(T) ' K. ' ]);
      disp(  '    Check the definition of the energy: Stokes=neutron losses energy=positive energy side');
      T = Sqw_getT(s);
    end

    % temperature stored ?
    T0        = Sqw_getT(s);

    % log_s_ratio should be about 0 if S(q,w) is symmetric
    classical = [];
    if ~isfinite(T) && ~isnan(T)
      classical = 1;
      T         = Sqw_getT(s);
    elseif T <= 0.1
      classical = 0;
    elseif T > 3000
      classical = 1;
    else 
    end

    % display warnings when mismatch is found
    if ~isempty(classical0) && ~isempty(classical) && classical0 ~= classical
      if   classical0, classical_str='classical/symmetric';
      else             classical_str='experimental/Bose/quantum/asymmetric'; end
      disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' from ' s.Source ]);
      disp(['    indicates a ' classical_str ' S(|q|,w) 2D object, but the analysis of the data shows it is not.' ]);
    elseif isempty(classical0) && ~isempty(classical)
      setalias(s,'classical', classical);
    end

    if ~isempty(T0) && ~isempty(T) && ~isnan(T) && ~(0.9 < T/T0 & T/T0 < 1.1)
      disp([ mfilename ': WARNING: The data set ' s.Tag ' ' s.Title ' S(|q|,w) 2D object from ' s.Source ]);
      disp(['    indicates a Temperature T=' num2str(T0) ' [K], but the analysis of the data provides T=' num2str(T) ' [K].' ]);
    end
    if isempty(T0) && ~isempty(T) && ~isnan(T) && T > 0.1 && T < 3000
      disp([ mfilename ': INFO: Setting temperature T=' num2str(T) ' [K] for data set ' s.Tag ' ' s.Title ' S(|q|,w) 2D object from ' s.Source ]);
      s.Temperature = T;
    end
    
  end % energy axis has +/- 

% ------------------------------------------------------------------------------
function flag=strcmpm(str, words)
% multiple strcmp
%
% input:
%   str:   string or cellstr of tokens
%   words: string or cellstr of words to search

  flag = false;
  if ischar(str),   str=strread(str, '%s','delimiter',' ,; $()[]{}=|<>&"/\:"'''); end
  if ischar(words), words = strread(words, '%s'); end;
  for index=1:numel(words)
    if any(strcmpi(str, words{index}))
      flag = true; return;
    end
  end