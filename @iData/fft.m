function b = fft(a, op)
% c = fft(a) : computes the Discrete Fourier transform of iData objects
%
%   @iData/fft function to compute the Discrete Fourier transform of data sets
%     using the FFT algorithm.
%
% input:  a: object or array (iData)
% output: c: object or array (iData)
% ex:     t=linspace(0,1,1000); 
%         a=iData(t,0.7*sin(2*pi*50*t)+sin(2*pi*120*t)+2*randn(size(t)));
%         c=fft(a); plot(abs(c));
%
% Version: $Revision: 1.3 $
% See also iData, iData/ifft, iData/conv, FFT, IFFT

if nargin <= 1,
  op = 'fft';
else
  op = 'ifft';
end

% handle input iData arrays
if length(a(:)) > 1
  b =a;
  for index=1:length(a(:))
    b(index) = feval(mfilename,a(index), op);
  end
  b = reshape(b, size(a));
  return
end

% make sure axes are regularly binned
a = interp(a);

% Find smallest power of 2 that is > Ly
Ly=size(a);
for i=1:length(Ly)         
  NFFT(i)=pow2(nextpow2(Ly(i)));
end
% compute the FFT
s = getaxis(a, 'Signal'); % Signal/Monitor
e = get(a, 'Error');

% Fast Fourier transform (pads with zeros up to the next power of 2)
if strcmp(op, 'fft')
  S=fftn(s, NFFT)/prod(Ly);
else
  S=ifftn(s, NFFT)*prod(Ly);
end
if any(abs(e))
  if strcmp(op, 'fft')
    E=fftn(e, NFFT)*prod(Ly);
  else
    E=ifftn(e, NFFT)*prod(Ly);
  end
else
  E=0;
end

% restrict to the first half (FFT is wrapped)
R.type='()';
for i=1:length(NFFT)
  if strcmp(op, 'fft')
  R.subs{i} = 1:ceil(NFFT(i)/2);
  else
  R.subs{i} = 1:ceil(NFFT(i));
  end
end
S=subsref(S,R);
if any(abs(e))
  E=subsref(E,R);
end
if ~strcmp(op, 'fft')
  S=S*2;
  E=E*2;
end

% update object
b = copyobj(a);
cmd=a.Command;
[dummy, sl] = getaxis(a, '0');
Data = a.Data;
Data.Signal =S;
Data.Error  =E;

if ndims(a) == 1
  NFFT=prod(NFFT);
  Ly  =prod(Ly);
end
% new axes
for index=1:ndims(a)
  x = getaxis(a, index);
  x = unique(x);
  x = mean(diff(x));
  if strcmp(op, 'fft')
  f = 1/x/2*linspace(0,1,NFFT(index)/2);
  else
  f = 1/x*linspace(0,1,NFFT(index));
  end
  Data=setfield(Data,[ 'axis' num2str(index) ], f);
end
b.Data = Data;

% make new aliases/axes
g = getalias(b); g(1:3) = [];
setalias(b, g);
setalias(b,'Signal', 'Data.Signal');
setalias(b,'Error',  'Data.Error');
b = setalias(b, 'Signal', S, [  op '(' sl ')' ]);
% clear axes
setaxis (b, [], getaxis(b));
for index=1:ndims(a)
  [def, lab]= getaxis(a, num2str(index));
  if isempty(lab), lab=[ 'axis' num2str(index) ' frequency' ];
  else
    lab=[ lab ' frequency' ];
  end
  b=setalias(b,[ 'axis' num2str(index) ], [ 'Data.axis' num2str(index) ], lab);
  b=setaxis (b, index, [ 'axis' num2str(index) ]);
end  
b.Command=cmd;
b = iData_private_history(b, op, a);  
