%% Parallelized Parameter Sweeping of Simscape Model with Rapid Accelerator

%% Instructions:
%
% Set your desired email under "Notification and backup setup". Also set up backup
% server info if desired.
%
% Set the time-out duration of the experiment (max time the experiment will
% run for)
%
% Set the name of the slx model file under "Prepare Model".
%
% Specify the parameter search space in "Parameters to search over"
%   Set the tunable parameter names (from the slx file) in sweptParamNames
%   Specify the corresponding search range for each parameter in
%   sweptParamRange
%
% Change the solver settings under "Setup solver settings"
%
% Set what data to save from each simulation run under "Specify what 
% simulation data to save"
%
% Run it and wait... you'll receive an email if something goes wrong, or 
% once it's done!

%% Clean up previous crap
clc; clear; close all

% Kill off previous worker pool if open
delete(gcp('nocreate'));

%% Add utils folder to path
addpath(genpath([pwd '/utils']));

%% Notification and backup setup
notify_recip = {'avolkovjr@cmu.edu'};
bkpServer = 'rustechs.ftp.sh';
bkpUser = 'sshBackup';
bkpPass = 'sshBackup';
remoteDir = '~/16711-final-proj-data';

% Create a UID for this experiment
datetime=datestr(now);
datetime=strrep(datetime,':','_'); %Replace colon with underscore
datetime=strrep(datetime,'-','_'); %Replace minus sign with underscore
datetime=strrep(datetime,' ','_'); %Replace space with underscore
expID = ['exp_' datetime];

%% Set up SSH java lib
javaaddpath([pwd '/utils/ssh/ganymed-ssh2-build250/ganymed-ssh2-build250.jar']);

%% Simulation Duration
tDuration = 1;

%% Prepare Model
mdl = 'simTopLevel';
% Might be able to replace with "load_system(mdl)" but not sure... they
% should be identical, except "load_system" doesn't open a simulink window
load_system(mdl);

% Load the model properties from a MATLAB file
ws = get_param(mdl,'ModelWorkspace');
ws.DataSource = 'MATLAB File';
ws.FileName = 'minitaurParameters';
ws.reload;

set_param(mdl,'SimMechanicsOpenEditorOnUpdate','off');

set_param(mdl,'SolverType','Variable-step');
set_param(mdl,'Solver','ode15s');
set_param(mdl,'SolverResetMethod','Fast');

%% Parameters to search over
% IMPORTANT -- The best I can tell, tunable parameters must be in global
% workspace, declared as Simulink.Parameter types with a SimulinkGlobal
% storage class...

sweptParamNames = {'tau0','tau1'};
sweptParamRange = {linspace(0.1,3,2), linspace(0.1,3,2)};

sweptParams = struct('name',sweptParamNames,'values',sweptParamRange);

for idx = 1:length(sweptParamNames)
    assignin('base',sweptParamNames{idx},Simulink.Parameter(1));
    eval([sweptParamNames{idx} '.CoderInfo.StorageClass = ''SimulinkGlobal''']);
end

%% Build it!
rtp = Simulink.BlockDiagram.buildRapidAcceleratorTarget(mdl);
% Close/unload without saving... can also save if needed, but this will 
% overwrite settings saved with the slx file.
close_system(mdl,0);

%% Set up the parameter sets object

idx=arrayfun(@(p) (1:length(p.values)), ...
                sweptParams, 'UniformOutput', false);
[idx{:}] = ndgrid(idx{:});

sweptParamValSets = arrayfun(@(p,idx) reshape(p.values(idx{1}),[],1),sweptParams, idx, 'UniformOutput', false);
sweptParamValSets = num2cell(reshape(cell2mat(sweptParamValSets),[],length(sweptParamNames)),length(sweptParamNames));

str = [strjoin(cellfun(@(name)['''' name ''''],sweptParamNames,'UniformOutput',false),',%g,') ',%g'];
                        
paramSets = cellfun(@(vals)evalin('base',['Simulink.BlockDiagram.modifyTunableParameters(rtp,' sprintf(str,vals) ');']),sweptParamValSets,'UniformOutput',false);
    
numParamSets = length(paramSets);

simCmdParamValStructs = cell(1, numParamSets);

%% Setup solver options

paramValStruct.AbsTol = 'auto';
paramValStruct.RelTol = '1e-3';
paramValStruct.MinStep = '1e-12';
paramValStruct.MaxStep = '1';
paramValStruct.MaxOrder = '2';
paramValStruct.ZeroCrossControl = 'UseLocalSettings';
paramValStruct.ZeroCrossAlgorithm = 'Adaptive';

paramValStruct.StopTime = num2str(tDuration);
paramValStruct.CaptureErrors = 'on';
paramValStruct.SimulationMode = 'rapid';
paramValStruct.RapidAcceleratorUpToDateCheck = 'off';
paramValStruct.RapidAcceleratorParameterSets = [];

%% Specify what simulation data to save
paramValStruct.ReturnWorkspaceOutputs = 'on';
paramValStruct.SignalLogging = 'on';
paramValStruct.SignalLoggingName = 'loggedSignals';

% Saving state might be useful for smaller models
% paramValStruct.SaveState = 'on';
% paramValStruct.StateSaveName = 'simState';

for idx = 1:numParamSets
        simCmdParamValStructs{idx} = paramValStruct;
        simCmdParamValStructs{idx}.RapidAcceleratorParameterSets = ...
            paramSets{idx};
end

%% Start the clock!
tic

%% Run the experiment trials in parallel!
% Wrapped in a try-catch to survive individual experiment failures

err = [];
try
    % Set up parfor parallelization
    parpool;

    out = cell(1, numParamSets);

    parfor_progress(numParamSets);

    parfor i = 1:numParamSets

        simout = sim(mdl,simCmdParamValStructs{i});

        out{i} = simout.get('loggedSignals');
        
        parfor_progress;

    end

catch err
    warning(['The following bad thing happened: ' getReport(err)]);
    msg = sprintf('Something went wrong @ %s', datestr(now));
    send_msg(notify_recip, expID, [msg '\n\n' getReport(err)]);
end

% Delete the temp progress bar file
parfor_progress(0);

% Close down the parallel worker pool
delete(gcp('nocreate'))

% Stop the clock
toc;

% Notify of successful completion
if isempty(err)
    msg = sprintf('%s: The simulation finished @ %s',expID,datestr(now));
    disp(msg);
    send_msg(notify_recip, expID, msg);
end

% Save Simulation Results for Post-Processing
% Note: this should run even if error is caught above.
saveAndBackupData(bkpServer,bkpUser,bkpPass,[pwd '/simData/' expID],remoteDir,notify_recip,out,expID);
