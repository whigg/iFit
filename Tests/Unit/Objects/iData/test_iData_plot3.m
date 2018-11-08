function result=test_iData_plot3

  h = plot3([ iData(peaks),iData(flow) ]);

  close(gcf);
  
  if numel(h) == 2
    result = [ 'OK     ' mfilename ];
  else
    result = [ 'FAILED ' mfilename ];
  end
