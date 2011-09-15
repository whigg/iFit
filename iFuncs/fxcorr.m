function y=fxcorr(x, h, shape)
%FCONV Correlation
%   y = FXCORR(x, h) correlates x and h.
%   It works with x and h being of any dimensionality. When only one argument is given, 
%     the auto-correlation is computed.
%   This is the same as calling 
%     fconv(x,h, 'correlation');
%
%      x = input vector (signal)
%      h = input vector (filter)
%  shape = optional shape of the return value
%          full         Returns the full two-dimensional correlation.
%          same         Returns the central part of the correlation of the same size as x.
%          valid        Returns only those parts of the correlation that are computed
%                       without the zero-padded edges. Using this option, y has size
%                       [mx-mh+1,nx-nh+1] when all(size(x) >= size(h)).
%          pad          Pads the x signal by replicating its starting/ending values
%                       in order to minimize the correlation side effects.
%          center       Centers the h filter so that correlation does not shift
%                       the x signal.
%          normalize    Normalizes the h filter so that the correlation does not
%                       change the x signal integral.
%          background   Remove the background from the filter h (subtracts the minimal value)
%
% ex:     c=fxcorr(a,b);
%
%      See also FCONV, CONV, CONV2, FILTER, FILTER2, FFT, IFFT
%
% Version: $Revision: 1.1 $
if nargin == 0, return; end
if nargin == 1, h = x; end
if nargin < 3, shape = ''; end
y=fconv(x,h, [ shape ' correlation'] );