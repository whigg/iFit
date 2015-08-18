function signal=sqw_ph_ase(configuration)
% model=sqw_ph_ase(configuration)
%
%   iFunc/sqw_ph_ase: computes phonon dispersions using the ASE.
%   A model which computes phonon dispersions from the forces acting between
%     atoms. The input argument is any configuration file describing the
%     material, e.g. cif, pdb, POSCAR, supported by ASE.
%   The phonon spectra is computed using the EMT calculator supported by the
%   Atomic Simulation Environment (ASE) <https://wiki.fysik.dtu.dk/ase>.
%   When performing a model evaluation, the DOS is also computed and stored
%   in model.UserData.DOS as an iData object.
%
% WARNING: Single intensity and line width parameters are used here.
%   This model is only suitable to compute phonon dispersions for e.g solid-
%   state materials.
%
% The argument should be:
% configuration: file name to an existing material configuration
%   Any A.S.E supported format can be used. 
%   See <https://wiki.fysik.dtu.dk/ase/ase/io.html#module-ase.io>
%
% Once the model has been created, its use requires that axes are given on
% regular qx,qy,qz grids.
%     
% Example:
%   s=sqw_ph_ase([ ifitpath 'Data/POSCAR_Al']);
%   qh=linspace(0,.5,50);qk=qh; ql=qh; w=linspace(0.01,100,51);
%   f=iData(s,[],qh,qk,ql,w); scatter3(log(f(1,:, :,:)),'filled');
%
% References: https://en.wikipedia.org/wiki/Phonon
% Atomic Simulation Environment
%   S. R. Bahn and K. W. Jacobsen, Comput. Sci. Eng., Vol. 4, 56-66, 2002
%   https://wiki.fysik.dtu.dk/ase>
%
% input:  p: sqw_ph_ase model parameters (double)
%             p(1)=Amplitude
%             p(2)=Gamma   dispersion DHO half-width in energy [meV]
%             p(3)=Background (constant)
%             p(4)=Temperature of the material [K]
%          or p='guess'
%         qh: axis along QH in rlu (row,double)
%         qk: axis along QK in rlu (column,double)
%         ql: axis along QL in rlu (page,double)
%         w:  axis along energy in meV (double)
%    signal: when values are given, a guess of the parameters is performed (double)
% output: signal: model value

signal = [];
if nargin == 0
  configuration = fullfile(ifitpath,'Data','POSCAR_Al');
end

status = sqw_ph_ase_requirements;

% BUILD stage: we call ASE to build the model
% calculator: can use EMT, EAM, lj, morse
%   or GPAW,abinit,gromacs,jacapo,nwchem,siesta,vasp,dacapo (when installed)
%
% from gpaw import GPAW
% from ase.calculators.dacapo import Dacapo

pw = pwd; target = tempname; mkdir(target);

% start python --------------------------
script = { ...
  'from ase.calculators.emt import EMT', ...
  'from ase.phonons import Phonons', ...
  'import ase.io', ...
  'import pickle', ...
  '# Setup crystal and calculator', ...
[ 'configuration = ''' configuration '''' ], ...
  'atoms = ase.io.read(configuration)', ...
  'calc  = EMT()', ...
  '# Phonon calculator', ...
  'N = 7', ...
  'ph = Phonons(atoms, calc, supercell=(N, N, N), delta=0.05)', ...
  'ph.run()', ...
  '# Read forces and assemble the dynamical matrix', ...
  'ph.read(acoustic=True)', ...
  '# save ph', ...
[ 'fid = open(''' target '/ph.pkl'',''wb'')' ], ...
  'pickle.dump(ph, fid)', ...
  'fid.close()' };
% end   python --------------------------

% write the script in the target directory
fid = fopen(fullfile(target,'sqw_ph_ase_build.py'),'w');
fprintf(fid, '%s\n', script{:});
fclose(fid);
% copy the configuration into the target
copyfile(configuration, target);

% call python script
cd(target)
disp([ mfilename ': creating Phonon/ASE model from ' target ]);
if isunix, precmd = 'LD_LIBRARY_PATH= ; '; else precmd=''; end
result = '';
try
  [status, result] = system([ precmd 'python sqw_ph_ase_build.py' ]);
  disp(result)
catch
  disp(result)
  error([ mfilename ': failed calling ASE with script ' ...
    fullfile(target,'sqw_ph_ase_build.py') ]);
end
cd(pw)

% then read the pickle file to store it into the model
signal.UserData.ph_ase = fileread(fullfile(target, 'ph.pkl')); % binary

signal.Name           = [ 'S(q,w) 3D dispersion Phonon/ASE with DHO line shape [' mfilename ']' ];

signal.Description    = [ 'S(q,w) 3D dispersion Phonon/ASE with DHO line shape. ' configuration ];

signal.Parameters     = {  ...
  'Amplitude' ...
  'Gamma Damped Harmonic Oscillator width in energy [meV]' ...
  'Background' ...
  'Temperature [K]' ...
   };
  
signal.Dimension      = 4;         % dimensionality of input space (axes) and result

signal.Guess = [ 1 .1 0 10 ];

signal.UserData.configuration = fileread(configuration);
signal.UserData.dir           = target;

% EVAL stage: we call ASE to build the model

signal.Expression = { ...
  '% check if directory and phonon pickle is here', ...
[ 'pw = pwd; target = this.UserData.dir;' ], ...
  'if ~isdir(target), target = tempname; mkdir(target); this.UserData.dir=target; end', ...
[ 'if isempty(dir(fullfile(target, ''ph.pkl'')))' ], ...
  '  fid=fopen(fullfile(target, ''ph.pkl''), ''w'');', ...
  '  if fid==-1, error([ ''model '' this.Name '' '' this.Tag '' could not write ph.pkl into '' target ]); end', ...
  '  fprintf(fid, ''%s\n'', this.UserData.ph_ase);', ...
  '  fclose(fid);', ...
  'end', ...
[ '  fid=fopen(fullfile(target,''sqw_ph_ase_eval.py''),''w'');' ], ...
[ '  fprintf(fid, ''# Script file for Python/ASE to compute the modes from ' configuration ' in %s\n'', target);' ], ...
  '  fprintf(fid, ''#   ASE: S. R. Bahn and K. W. Jacobsen, Comput. Sci. Eng., Vol. 4, 56-66, 2002\n'');', ...
  '  fprintf(fid, ''#   <https://wiki.fysik.dtu.dk/ase>\n'');', ...
  '  fprintf(fid, ''from ase.phonons import Phonons\n'');', ...
  '  fprintf(fid, ''import numpy\n'');', ...
  '  fprintf(fid, ''import pickle\n'');', ...
  '  fprintf(fid, ''# restore Phonon model\n'');', ...
  '  fprintf(fid, ''fid = open(''''ph.pkl'''', ''''rb'''')\n'');', ...
  '  fprintf(fid, ''ph = pickle.load(fid)\n'');', ...
  '  fprintf(fid, ''fid.close()\n'');', ...
  '  fprintf(fid, ''# read HKL locations\n'');', ...
  '  fprintf(fid, ''HKL = numpy.loadtxt(''''HKL.txt'''')\n'');', ...
  '  fprintf(fid, ''# compute the spectrum\n'');', ...
  '  fprintf(fid, ''omega_kn = 1000 * ph.band_structure(HKL)\n'');', ...
  '  fprintf(fid, ''# Calculate phonon DOS\n'');', ...
  '  fprintf(fid, ''omega_e, dos_e = ph.dos(kpts=(50, 50, 50), npts=5000, delta=5e-4)\n'');', ...
  '  fprintf(fid, ''omega_e *= 1000\n'');', ...
  '  fprintf(fid, ''# save the result in FREQ\n'');', ...
  '  fprintf(fid, ''numpy.savetxt(''''FREQ'''', omega_kn)\n'');', ...
  '  fprintf(fid, ''numpy.savetxt(''''DOS_w'''',omega_e)\n'');', ...
  '  fprintf(fid, ''numpy.savetxt(''''DOS'''',  dos_e)\n'');', ...
  '  fprintf(fid, ''exit()\n'');', ...
  '  fclose(fid);', ...
  '  sz0 = size(t);', ...
  '  if ndims(x) == 4, x=squeeze(x(:,:,:,1)); y=squeeze(y(:,:,:,1)); z=squeeze(z(:,:,:,1)); t=squeeze(t(1,1,1,:)); end',...
  'try', ...
  '  cd(target);', ...
  '  HKL = [ x(:) y(:) z(:) ];', ...
  '  save -ascii HKL.txt HKL', ...
[ '  [status,result] = system(''' precmd 'python sqw_ph_ase_eval.py'');' ], ...
  '  % import FREQ', ...
  '  FREQ=load(''FREQ'',''-ascii''); % in meV', ...
  '  DOS = load(''DOS'',''-ascii''); DOS_w = load(''DOS_w'',''-ascii''); DOS=iData(DOS_w,DOS);', ...
  '  DOS.Title = [ ''DOS '' this.Name ]; xlabel(DOS,''Energy [meV]''); DOS.Error=0; this.UserData.DOS=DOS;', ...
  'catch; disp([ ''model '' this.Name '' '' this.Tag '' could not run Python/ASE from '' target ]);', ...
  'end', ...
  '  cd(pw);', ...
  '  % multiply all frequencies(columns, meV) by a DHO/meV', ...
  '  Amplitude = p(1); Gamma=p(2); Bkg = p(3); T=p(4);', ...
  '  if T<=0, T=300; end', ...
  '  w=t(:) * ones(1,size(FREQ,1));', ...
  '  signal=zeros(size(w));', ...
  'for index=1:size(FREQ,2)', ...
  '% transform w and w0 to same size', ...
  '  w0= ones(numel(t),1) * FREQ(:,index)'';', ...
  '  toadd = Amplitude*Gamma *w0.^2.* (1+1./(exp(abs(w)/T)-1)) ./ ((w.^2-w0.^2).^2+(Gamma*w).^2);', ...
  '  signal = signal +toadd;', ...
  'end', ...
  'signal = reshape(signal'',sz0);' };

signal = iFunc(signal);

% when model is successfully built, display citations for ASE
disp([ mfilename ': Model ' configuration ' built using: (please cite)' ])
disp(' *Atomic Simulation Environment')
disp('     S. R. Bahn and K. W. Jacobsen, Comput. Sci. Eng., Vol. 4, 56-66, 2002')
disp('     <https://wiki.fysik.dtu.dk/ase>. LGPL license.')
disp(' * iFit: E. Farhi et al, J. Neut. Res., 17 (2013) 5.')
disp('     <http://ifit.mccode.org>. EUPL license.')


% ------------------------------------------------------------------------------
function status = sqw_ph_ase_requirements

% test for ASE in Python
if isunix, precmd = 'LD_LIBRARY_PATH= ; '; else precmd=''; end
[status, result] = system([ precmd 'python -c "import ase.version; print ase.version.version"' ]);
if status ~= 0
  disp([ mfilename ': ERROR: requires ASE to be installed.' ])
  disp('  Get it at <https://wiki.fysik.dtu.dk/ase>.');clear all
  error([ mfilename ': ASE not installed' ]);
end

