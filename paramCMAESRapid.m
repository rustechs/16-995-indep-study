%% Parallelized Parameter Optimization (CMA-ES) of Simscape Model with Rapid Accelerator

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
%   Set the tunable parameter names (from the slx file) in tunedParamNames
%   Specify the corresponding search range for each parameter in
%   tunedParamRange
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

% Delete old parfor progress file if it's still around
if exist('parfor_progress.txt', 'file') == 2
  delete('parfor_progress.txt');
end

%% Add utils folder to path
addpath(genpath([pwd '/utils']));

%% Notification and backup setup
notify_recip = {};
bkpServer = 'rustechs.ftp.sh';
bkpUser = 'sshBackup';
bkpPass = 'sshBackup';
remoteDataDir = '~/16711-final-proj-data';

%% Disable warnings
warning('off','all');

%% Simulation Duration
tDuration = 1;

%% Prepare Model
mdl = 'simTopLevel';
% Might be able to replace with "load_system(mdl)" but not sure... they
% should be identical, except "load_system" doesn't open a simulink window
load_system(mdl);

% Load the model properties from a MATLAB file
ws = get_param(mdl,'ModelWorkspace');
ws.DataSource = 'Model File';

set_param(mdl,'SimMechanicsOpenEditorOnUpdate','off');
set_param(mdl,'SimulationMode','rapid-accelerator');
set_param(mdl,'SolverType','Variable-step');
set_param(mdl,'Solver','ode15s');
set_param(mdl,'SolverResetMethod','Fast');

%% Parameters to search over
% IMPORTANT -- The best I can tell, tunable parameters must be in global
% workspace, declared as Simulink.Parameter types with a SimulinkGlobal
% storage class...

tunedParamNames = {'ForeRearLag','Period'};
tunedParamInit = [0 1];

for idx = 1:length(tunedParamNames)
    assignin('base',tunedParamNames{idx},Simulink.Parameter(tunedParamInit(idx)));
    eval([tunedParamNames{idx} '.CoderInfo.StorageClass = ''SimulinkGlobal''']);
end

paramSetsStr = [strjoin(cellfun(@(name)['''' name ''''],tunedParamNames,'UniformOutput',false),',%g,') ',%g'];

%% Build it!
rtp = Simulink.BlockDiagram.buildRapidAcceleratorTarget(mdl);
% Close/unload without saving... can also save if needed, but this will 
% overwrite settings saved with the slx file.
close_system(mdl,0);

%% Setup solver options

simOptsStruct.AbsTol = 'auto';
simOptsStruct.RelTol = '1e-3';
simOptsStruct.MinStep = '1e-12';
simOptsStruct.MaxStep = '1';
simOptsStruct.MaxOrder = '2';
simOptsStruct.ZeroCrossControl = 'UseLocalSettings';
simOptsStruct.ZeroCrossAlgorithm = 'Adaptive';

simOptsStruct.StopTime = num2str(tDuration);
simOptsStruct.CaptureErrors = 'on';
simOptsStruct.SimulationMode = 'rapid';
simOptsStruct.RapidAcceleratorUpToDateCheck = 'off';


%% Specify what simulation data to save
simOptsStruct.ReturnWorkspaceOutputs = 'on';
simOptsStruct.SignalLogging = 'on';
simOptsStruct.SignalLoggingName = 'loggedSignals';

% Saving state might be useful for smaller models
% simOptsStruct.SaveState = 'on';
% simOptsStruct.StateSaveName = 'simState';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CMA-ES Initialization Goes Here

% Specify pointer to objective function, which takes in a simout object and
% outputs a scalar fitness value > 0
objFn = @fitnessFunc;

% Sets up CMA-ES optimization process
% Returns struct of invariant CMA-ES settings and 
% initial generation statistics struct. No changes to this fn necessary.
[cmaesSettings,genStats,topFitness,dataFolder] = initCMAES(tunedParamNames,tunedParamInit,objFn);

% Initialize previous generation data struct
prevGenStats = genStats;
prevGenStats.genNum = 0;

% Create structure to hold sim command arguments/options (including tuned 
% param values)
simCmdParamValStructs = cell(1,cmaesSettings.genSize);

for idx = 1:cmaesSettings.genSize
        simCmdParamValStructs{idx} = simOptsStruct;
end

% Initialize parallel worker pool
parpool('SpmdEnabled',false);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Outer (infinite) CMA-ES while loop 
%   Run CMA-ES until termination conditions are met, evaluated after each
%   generation. Termination settings are set in CMAESTerminateConditions.m

% Scroll output buffer up
home;

fprintf('\nBeginning CMA-ES optimization %s...\n',genStats.experimentID);

while true

    %% Run trials for each generation in parallel!
    % Wrapped in a try-catch to survive individual experiment failures -->
    % fitness set to inf in this case (TODO!!!)
    
    % Generate initial population conditions
    for k = 1:cmaesSettings.genSize
        genStats.paramVals{k} = genStats.paramMean + genStats.sigStep * genStats.B * (genStats.D .* randn(cmaesSettings.numParams,1)); % m + sig * Normal(0,C) 
        genStats.evalCount = genStats.evalCount+1;
    end
    
    % Create rapid parameter structure from tunable parameter values
    paramSets = cellfun(@(vals)evalin('base', ...
        ['Simulink.BlockDiagram.modifyTunableParameters(rtp,' sprintf(paramSetsStr,vals) ');']),genStats.paramVals,'UniformOutput',false);

    % Fill up sim command structure with param data
    for idx = 1:cmaesSettings.genSize
        simCmdParamValStructs{idx}.RapidAcceleratorParameterSets = paramSets{idx};
    end
    
    fprintf('\nStarting generation %i...\n\n',genStats.genNum);
    
    err = [];
    try
        
        % Output of each trial run
        out = cell(1,cmaesSettings.genSize);

        % Set up parfor progress display
        parfor_progress(cmaesSettings.genSize);
       
        parfor i = 1:cmaesSettings.genSize

            simout = sim(mdl,simCmdParamValStructs{i});

            out{i} = simout.get('loggedSignals');

            % Update parfor status for current generation
            parfor_progress;
            
        end

    catch err
        warning(['The following bad thing happened: ' getReport(err)]);
        msg = sprintf('%s: Something went wrong @ %s',genStats.experimentID,datestr(now));
        if ~isempty(notify_recip)
            send_msg(notify_recip, genStats.experimentID, [msg '\n\n' getReport(err,'extended','hyperlinks','off')]);
        end
    end

    % Delete the temp progress bar file
    parfor_progress(0);
    
    %% TODO: Toss this into the parfor??
    % Compute fitness data of this generation from results in out{i}
    genStats.fitness = cellfun(@(trialData) objFn(trialData),out);
    [~,fitnessOrder] = sort(genStats.fitness);

    % Notify of successful generation completion
    if isempty(err)
        msg = sprintf('%s: Generation %d finished @ %s',genStats.experimentID,genStats.genNum,datestr(now));
        fprintf('\n%s\n',msg);
        fprintf('Top fitness in gen %d: %g\n',genStats.genNum,max(genStats.fitness));
        if ~isempty(notify_recip)
            send_msg(notify_recip, genStats.experimentID, msg);
        end
    end    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %% CMA-ES Post-Process the generation's data 
    %   Compute fitness
    %   figure out if end conditions are met
    %       Break if they are
    %       Otherwise, prepare next generation
    
    % Save generation data to file and backup
    saveAndBackupGenData(bkpServer,bkpUser,bkpPass,dataFolder,[remoteDataDir '/' genStats.experimentID],notify_recip,genStats);
    
    fprintf([repmat('-',1,80) '\n']);
    
    % Termination conditions set in CMAESTerminateConditions
    if CMAESTerminateConditions(prevGenStats,genStats) 
        % End conditions met --> end CMA-ES routine and perform final ops
        break;
    else 
        % End conditions not met yet --> create next generation
        
        % Save current gen to prev gen stats variable
        prevGenStats = genStats;
 
        % Create a matrix of param values size [numParams genSize], with
        % rows (trials of generation) reordered by fitness in ascending
        % order.
        sortedParamValArray = cell2mat(genStats.paramVals(fitnessOrder)');
        
        % Compute weighted mean of all paramters
        weightsArray = repmat(genStats.weights',cmaesSettings.numParams,1);
        genStats.paramMean = dot(sortedParamValArray(:,1:cmaesSettings.mu),weightsArray,2);  
        
        genStats.pathSig = (1-cmaesSettings.tauSig)*genStats.pathSig + sqrt(cmaesSettings.tauSig*(2-cmaesSettings.tauSig)*cmaesSettings.muEff) * genStats.invsqrtC * (genStats.paramMean-prevGenStats.paramMean) / genStats.sigStep; 
        hsig = norm(genStats.pathSig)/sqrt(1-(1-cmaesSettings.tauSig)^(2*genStats.evalCount/cmaesSettings.genSize))/cmaesSettings.chiN < 1.4 + 2/(cmaesSettings.numParams+1);
        genStats.pathC = (1-cmaesSettings.tauC)*genStats.pathC + hsig * sqrt(cmaesSettings.tauC*(2-cmaesSettings.tauC)*cmaesSettings.muEff) * (genStats.paramMean-prevGenStats.paramMean) / genStats.sigStep;

        % Adapt covariance matrix C
        artmp = (1/genStats.sigStep) * (sortedParamValArray(:,1:cmaesSettings.mu)-repmat(prevGenStats.paramMean,1,cmaesSettings.mu));
        genStats.paramCovar = (1-cmaesSettings.rate1C-cmaesSettings.rateMuC) * genStats.paramCovar ...                  % regard old matrix  
           + cmaesSettings.rate1C * (genStats.pathC*genStats.pathC' ...                 % plus rank one update
                   + (1-hsig) * cmaesSettings.tauC*(2-cmaesSettings.tauC) * genStats.paramCovar) ... % minor correction if hsig==0
           + cmaesSettings.rateMuC * artmp * diag(genStats.weights) * artmp'; % plus rank mu update

        % Adapt step size sigma
        genStats.sigStep = genStats.sigStep * exp((cmaesSettings.tauSig/cmaesSettings.dampSig)*(norm(genStats.pathSig)/cmaesSettings.chiN - 1)); 
    
        % Decomposition of C into B*diag(D.^2)*B' (diagonalization)
        if genStats.evalCount - genStats.eigenEvalCount > cmaesSettings.genSize/(cmaesSettings.rate1C+cmaesSettings.rateMuC)/cmaesSettings.numParams/10  % to achieve O(N^2)
            genStats.eigenEvalCount = genStats.evalCount;
            genStats.paramCovar = triu(genStats.paramCovar) + triu(genStats.paramCovar,1)'; % enforce symmetry
            [genStats.B,genStats.D] = eig(genStats.paramCovar);           % eigen decomposition, B==normalized eigenvectors
            genStats.D = sqrt(diag(genStats.D));        % D is a vector of standard deviations now
            genStats.invsqrtC = genStats.B * diag(genStats.D.^-1) * genStats.B';
        end
        
        genStats.genNum = genStats.genNum + 1;
        
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end

% Close down the parallel worker pool
delete(gcp('nocreate'));

%% What happens after optimization ends?

msg = sprintf('CMA-ES Optimization (%s) Completed @ %s\n\n', genStats.experimentID, datestr(now));
fprintf('\n%s\n', msg);
if ~isempty(notify_recip)
    send_msg(notify_recip, genStats.experimentID, msg);
end

% Save final generation raw data for post-processing
% Note: this should run even if error is caught above.
saveAndBackupData(bkpServer,bkpUser,bkpPass,dataFolder,[remoteDataDir '/' genStats.experimentID],notify_recip,out,genStats.experimentID);
