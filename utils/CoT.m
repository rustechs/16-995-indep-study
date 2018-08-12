function c = CoT(Pin,d,t,Msys)
% Calculate cost of transport

    % Params
    g = 9.81;
    
    % Compute total travel distance
    dTravel = abs(range(d));
    
    % Compute total input energy
    Eavg = trapz(t,abs(Pin));
    
    % Compute CoT
    c = Eavg/(Msys*g*dTravel);

end