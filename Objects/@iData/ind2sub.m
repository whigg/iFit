function data = ind2sub(data, indexes)
% ind2sub(s,index) : get indexed element in an iData array
%
%   @iData/ind2sub is equivalent to accessing directly the indexed element in arrays,
%         except when the array is of lenght 1.
%         When length(s) is 1, s(1) would return s itself,
%         whereas ind2sub(s,1) returns the first element of its 'Signal',
%
% input:  s:     object or array (iData)
%         index: index in array
% output: s(index)
% ex :    ind2sub(s, 1)
%
% Version: $Revision: 1.3 $
% See also iData, iData/disp, iData/get, iData/size

% EF 23/09/07 iData implementation
% ind2sub 
  if nargin < 2, indexes=[]; end
  if ~length(indexes), data=[]; return; end
  valid = find(indexes > 0 & indexes <= numel(data));
  indexes = indexes(valid);
  if length(data) > 1, 
    data=data(indexes);
  else
    if length(data) == 0, data=[]; 
    else 
    	S = data.Signal;
    	data = S(1);
    end
  end    