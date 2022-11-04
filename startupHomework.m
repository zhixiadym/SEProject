close hidden all;
clear hidden all;
clear all classes;

format compact;
dbstop if error;
% dbstop if caught error;
set(groot, 'defaulttextinterpreter','none') 
set(groot, 'DefaultTextInterpreter', 'none')
set(groot, 'DefaultLegendInterpreter', 'none')
set(groot, 'defaultFigurePaperPositionMode', 'auto')

%% clean up class definitions
clear mclasses;

%% path variables
% rootpath = fullfile('/Users/daiyamin/Downloads/SEhomeworkCode');
rootpath = fullfile('/Users/daiyamin/Downloads/SEhomeworkCode');
addpath(fullfile(rootpath, 'sharedLibrary',  'utils'));
addpath(genpath_exclude(rootpath, {'.git', '.ignore', 'data', 'results', 'serializedData', 'reports', 'doc', '+mclasses'}));

STATICPARS = mclasses.staticParameters.StaticParameters;

%% add CVX path (CAUTIOM: make sure CVX is installed OUTSIDE of the above rootpath directory)
cvxPath = '/Users/daiyamin/Downloads/cvx/';
cd(cvxPath)
% cvx_setup 'D:\courses\software engineering\2019.M4.SoftwareEngineering\cvxlicense\cvx_license.dat'

%% project directory
PROJECTPATH = fullfile(rootpath);

%% final touch
cd(PROJECTPATH); 
