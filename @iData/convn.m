function c = convn(a,b)
% c = convn(a,b) : computes the convolution of an iData object with a response function 
%
%   @iData/convn function to compute the convolution of data sets with automatic centering
%     and normalization of the filter. This is a shortucut for
%       conv(a,b, 'same pad background center normalize')
%
% input:  a: object or array, signal (iData or numeric)
%         b: object or array, filter (iData or numeric)
% output: c: object or array (iData)
% ex:     c=convn(a,b);
%
% Version: $Revision: 1.1 $
% See also iData, iData/conv, iData/times, conv, convn, conv2, filter2, fft
if nargin ==1
	b=[];
end
c = iData_private_binary(a, b, 'conv', 'same pad background center normalize');
