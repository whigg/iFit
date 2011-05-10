function [pars,fval,exitflag,output] = fminrand(varargin)
% [MINIMUM,FVAL,EXITFLAG,OUTPUT] = fminrand(FUN,PARS,[OPTIONS],[CONSTRAINTS]) adaptive random search optimizer
%
% This minimization method uses an adaptive random search.
% 
% Calling:
%   fminrand(fun, pars) asks to minimize the 'fun' objective function with starting
%     parameters 'pars' (vector)
%   fminrand(fun, pars, options) same as above, with customized options (optimset)
%   fminrand(fun, pars, options, fixed) 
%     is used to fix some of the parameters. The 'fixed' vector is then 0 for
%     free parameters, and 1 otherwise.
%   fminrand(fun, pars, options, lb, ub) 
%     is used to set the minimal and maximal parameter bounds, as vectors.
%   fminrand(fun, pars, options, constraints) 
%     where constraints is a structure (see below).
%
% Example:
%   banana = @(x)100*(x(2)-x(1)^2)^2+(1-x(1))^2;
%   [x,fval] = fminrand(banana,[-1.2, 1])
%
% Input:
%  FUN is the function to minimize (handle or string).
%
%  PARS is a vector with initial guess parameters. You must input an
%  initial guess.
%
%  OPTIONS is a structure with settings for the optimizer, 
%  compliant with optimset. Default options may be obtained with
%     o=fminbfgs('defaults')
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
% Reference: A.R. Secchi and C.A. Perlingeiro, "Busca Aleatoria Adaptativa",
%   in Proc. of XII Congresso Nacional de Matematica Aplicada e
%   Computacional, Sao Jose do Rio Preto, SP, pp. 49-52 (1989).
% Contrib: Argimiro R. Secchi (arge@enq.ufrgs.br) 2001
% Modified by Giovani Tonel(giovani.tonel@ufrgs.br) on September 2006
%
% Version: $Revision: 1.18 $
% See also: fminsearch, optimset

% default options for optimset
if nargin == 0 || (nargin == 1 && strcmp(varargin{1},'defaults'))
  options=optimset; % empty structure
  options.Display='';
  options.TolFun =1e-3;
  options.TolX   =1e-8;
  options.MaxIter=1000;
  options.MaxFunEvals=5000;
  options.algorithm  = [ 'Adaptive Random Search (by Secchi) [' mfilename ']' ];
  options.optimizer = mfilename;
  pars = options;
  return
end

[pars,fval,exitflag,output] = fmin_private_wrapper(mfilename, varargin{:});

