function fit = fitnessFunc(simData)

    bodPos = simData.getElement('bodPos').Values.Data;
    Pin = sum(simData.getElement('P_elec').Values.Data,2);
    
    t = simData.getElement('bodPos').Values.Time;
    
    idx = find(t > 0.1);
    
    dTravel = bodPos(idx,2);
    Pin = Pin(idx);
    tTravel = t(idx);

    fit = CoT(Pin,dTravel,tTravel,6.36);

end