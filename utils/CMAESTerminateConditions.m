function term = CMAESTerminateConditions(prevGenStats,curGenStats)
%% Termination conditions for CMA-ES optimization
% Output is true if termination conditions are met, otherwise false

   term = false;

   stopFitness = 1e-10;  % stop if fitness < stopFitness (minimization)
   stopFitnessDelta = 1e-12; % stop if change in fitness < stopFitnessDelta (convergence)
   maxGens = 4;
   
   curGen = curGenStats.genNum;
   prevFitness = mean(prevGenStats.fitness);
   curFitness = mean(curGenStats.fitness);
   fitnessDelta = abs(curFitness - prevFitness);
   
   % Have we reached a desired fitness
   isFitnessGoodEnough = curFitness < stopFitness;
   
   % Have we run enough generations?
   isEnoughGens = curGen >= maxGens;
   
   % Has the progress plateau'd? 
   % Requires additional state variable to keep track of fitness history
   % Might be worth looking at covariance of parameters as indicator of
   % "certainty"?
   % isFitnessPlateau = 
   
   if  isFitnessGoodEnough || isEnoughGens %|| isFitnessPlateau
       term = true;
   end
   
end