function result = test_Plot_10_caxis
  a=iData(peaks); plot(a); caxis(del2(a));
  result = 'OK  caxis';
