function result=test_iData_load

  a=iData([ ifitpath 'Data/30dor.fits' ]);
  b=iData([ ifitpath 'Data/Diff_BananaTheta_1314088587.th' ]);
  
  if all(~isempty([ a b]))
    result = [ 'OK     ' mfilename ];
  else
    result = [ 'FAILED ' mfilename ];
  end
