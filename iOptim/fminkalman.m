function [pars,fval,exitflag,output] = fminkalman(varargin)
% [MINIMUM,FVAL,EXITFLAG,OUTPUT] = fminkalman(FUN,PARS,[OPTIONS],[CONSTRAINTS]) unscented Kalman filter optimizer
%
% Unconstrained optimization using the unscented Kalman filter.
% The Kalman filter is actually a feedback approach to minimize the estimation 
% error in terms of sum of square. This approach can be generalized to general 
% nonlinear optimization. This function shows a way using the extended Kalman 
% filter to solve some unconstrained nonlinear optimization problems.
% 
% Calling:
%   fminkalman(fun, pars) asks to minimize the 'fun' objective function with starting
%     parameters 'pars' (vector)
%   fminkalman(fun, pars, options) same as above, with customized options (optimset)
%   fminkalman(fun, pars, options, fixed) 
%     is used to fix some of the parameters. The 'fixed' vector is then 0 for
%     free parameters, and 1 otherwise.
%   fminkalman(fun, pars, options, lb, ub) 
%     is used to set the minimal and maximal parameter bounds, as vectors.
%   fminkalman(fun, pars, options, constraints) 
%     where constraints is a structure (see below).
%
% Example:
%   banana = @(x)100*(x(2)-x(1)^2)^2+(1-x(1))^2;
%   [x,fval] = fminkalman(banana,[-1.2, 1])
%
% Input:
%  FUN is a function handle (anonymous function or inline) with a loss
%  function, which may be of any type, and needn't be continuous. It does,
%  however, need to return a single value.
%
%  PARS is a vector with initial guess parameters. You must input an
%  initial guess.
%
%  OPTIONS is a structure with settings for the simulated annealing, 
%  compliant with optimset. Default options may be obtained with
%     o=fminkalman('defaults')
%
%  CONSTRAINTS may be specified as a structure
%   constraints.min=   vector of minimal values for parameters
%   constraints.max=   vector of maximal values for parameters
%   constraints.fixed= vector having 0 where parameters are free, 1 otherwise
%   constraints.step=  vector of maximal parameter changes per iteration
%
% Output:
%          MINIMUM is the solution which generated the smallest encountered
%            value when input into FUN.
%          FVAL is the value of the FUN function evaluated at MINIMUM.
%          EXITFLAG return state of the optimizer
%          OUTPUT additional information returned as a structure.
%
% Reference:
%  Kalman, R. E. "A New Approach to Linear Filtering and Prediction Problems,
%    Transactions of the ASME - J. of Basic Engineering Vol. 82: pp. 35 (1960)
%  http://en.wikipedia.org/wiki/Kalman_filter
% Contrib:
%   By Yi Cao at Cranfield University, 08 January 2008 [ukfopt, ukf]
%
% Version: $Revision: 1.15 $
% See also: fminsearch, optimset

% default options for optimset
if nargin == 0 || (nargin == 1 && strcmp(varargin{1},'defaults'))
  options=optimset; % empty structure
  options.Display='';
  options.TolFun =1e-3;
  options.TolX   =1e-8;
  options.MaxIter=1000;
  options.MaxFunEvals=1000;
  options.algorithm  = [ 'unscented Kalman filter optimizer (by Cao) [' mfilename ']' ];
  options.optimizer = mfilename;
  pars = options;
  return
end


[pars,fval,exitflag,output] = fmin_private_wrapper(mfilename, varargin{:});
