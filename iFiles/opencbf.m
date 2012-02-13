function out = opencbf(filename)
%OPENCBF Open a Crystallographic Binary File, display it
%        and set the 'ans' variable to an iData object with its content

out = iData(filename);
plot(out);

if ~isdeployed
  assignin('base','ans',out);
  ans = out
end