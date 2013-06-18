function result = test_Fit_4_fminplot
  a=load(iData, [ ifitpath 'Data/sv1850.scn' ]);
  options=fminimfil('defaults');
  options.OutputFcn='fminplot';
  p= fits(a, 'gauss', [], options);
  % p=[ 0.6263    1.0008   -0.0037    0.0002 ]
  b = a(gauss, p);
  figure; plot([ a b ]);
  if max(a-b)/mean(get(a,'Monitor')) < 0.1
    result = 'OK  fits(a, ''gauss'', [], options.OutputFcn=''fminplot'')';
  else 
    result = 'FAILED';
  end 
