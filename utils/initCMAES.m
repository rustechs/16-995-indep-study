function [cmaesSettings,genStatsInit,topFitness,dataFolder] = initCMAES(paramNames,paramValsInit,objFn)

    % Create a UID for this experiment
    datetime=datestr(now);
    datetime=strrep(datetime,':','_'); %Replace colon with underscore
    datetime=strrep(datetime,'-','_'); %Replace minus sign with underscore
    datetime=strrep(datetime,' ','_'); %Replace space with underscore

    % Generation population information held in structure genStatsInit
    % Size of each generation given by genSize
    % Paramter values for current generation given in paramVals

    % This struct gets updated after each generation, but is saved to disk first 
    % for post-processing. This way, the history of the optimization can be
    % evaluated afterwards, without having to keep the history in memory at
    % runtime.

    genStatsInit.experimentID = ['exp_' datetime];
    genStatsInit.genNum = 1;
    genStatsInit.paramNames = paramNames;
                  
    % Create data folder for this experiment
    dataFolder = [pwd '/simData/' genStatsInit.experimentID];
    mkdir(dataFolder); 

    % Invariant settings specific to the optimization process used are saved to
    % the cmaesSettings struct:

    % handle to objective/fitness function
    cmaesSettings.objFn = objFn;

    % number of objective variables/problem dimension
    cmaesSettings.numParams = length(paramNames); 

    % size of each generation
    cmaesSettings.genSize = 4+floor(3*log(cmaesSettings.numParams));

    % Strategy parameter setting: Selection
    mu = cmaesSettings.genSize/2;               % number of parents/points for recombination
    weights = log(mu+1/2)-log(1:mu)'; % [mu x 1] array for weighted recombination
    
    cmaesSettings.mu = floor(mu);     
    
    genStatsInit.weights = weights/sum(weights);     % normalize recombination weights array
    
    cmaesSettings.muEff = sum(genStatsInit.weights)^2/sum(genStatsInit.weights.^2); % variance-effectiveness of sum w_i x_i

    % Strategy parameter setting: Adaptation
    cmaesSettings.tauC = (4+cmaesSettings.muEff/cmaesSettings.numParams) / (cmaesSettings.numParams+4 + 2*cmaesSettings.muEff/cmaesSettings.numParams);  % time constant for cumulation for C
    cmaesSettings.tauSig = (cmaesSettings.muEff+2) / (cmaesSettings.numParams+cmaesSettings.muEff+5);  % t-const for cumulation for sigma control
    cmaesSettings.rate1C = 2 / ((cmaesSettings.numParams+1.3)^2+cmaesSettings.muEff);    % learning rate for rank-one update of C
    cmaesSettings.rateMuC = min(1-cmaesSettings.rate1C, 2 * (cmaesSettings.muEff-2+1/cmaesSettings.muEff) / ((cmaesSettings.numParams+2)^2+cmaesSettings.muEff));  % and for rank-mu update
    cmaesSettings.dampSig = 1 + 2*max(0, sqrt((cmaesSettings.muEff-1)/(cmaesSettings.numParams+1))-1) + cmaesSettings.tauSig; % damping for sigma, usually close to 1

    % Initialize dynamic (internal) strategy parameters and constants
    genStatsInit.sigStep = 0.3; % coordinate wise standard deviation (step size)
    genStatsInit.pathC = zeros(cmaesSettings.numParams,1);   % evolution paths for C
    genStatsInit.pathSig = zeros(cmaesSettings.numParams,1);   % evolution paths for sigma
    genStatsInit.B = eye(cmaesSettings.numParams,cmaesSettings.numParams);                       % genStatsInit.B defines the coordinate system
    genStatsInit.D = ones(cmaesSettings.numParams,1);                      % diagonal genStatsInit.D defines the scaling
    genStatsInit.invsqrtC = genStatsInit.B * diag(genStatsInit.D.^-1) * genStatsInit.B';    % C^-1/2 
    genStatsInit.eigenEvalCount = 0;                      % track update of genStatsInit.B and genStatsInit.D
    cmaesSettings.chiN = cmaesSettings.numParams^0.5*(1-1/(4*cmaesSettings.numParams)+1/(21*cmaesSettings.numParams^2));  % expectation of 
                                      %   ||N(0,I)|| == norm(randn(N,1)) 

    % Each cell in genStatsInit.paramVals is a cmaesSettings.numParams vector
    % of parameter values corresponding to a trial in the generation
    genStatsInit.paramVals = cell(cmaesSettings.genSize,1);
    genStatsInit.evalCount = 0;

    % Generation covariance matrix C
    genStatsInit.paramCovar = genStatsInit.B * diag(genStatsInit.D.^2) * genStatsInit.B';   

    % Set initial parameter mean as specified parameter initial values
    genStatsInit.paramMean = reshape(paramValsInit,length(paramValsInit),1);  
    
    % Initialize fitness to infinity
    genStatsInit.fitness = inf*ones(cmaesSettings.genSize,1);

    % Save optimizer settings to generation data struct
    genStatsInit.optimParams = cmaesSettings;
    
    topFitness = 

end