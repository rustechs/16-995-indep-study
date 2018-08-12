% % Everything related to the minitaur is held within the struct
% minitaurParams.

% Parameters related to other components of the simulation, such as the
% controller or environment interaction model, should be saved within
% corresponding structs.



%% Minitaur Model

% Leg Linkage Geometry (FK/IK)
minitaurParams.Kinematics.L1 = 100e-3;
minitaurParams.Kinematics.L2 = 200e-3;

% Encoder Zeroing Offsets
minitaurParams.Sensing.Encoders.IA.Zero = -1.25*pi;
minitaurParams.Sensing.Encoders.IB.Zero = -0.25*pi;
minitaurParams.Sensing.Encoders.IIA.Zero = 1.25*pi;
minitaurParams.Sensing.Encoders.IIB.Zero = 1.25*pi;
minitaurParams.Sensing.Encoders.IIIA.Zero = 0.5*pi;
minitaurParams.Sensing.Encoders.IIIB.Zero = 1.5*pi;
minitaurParams.Sensing.Encoders.IVA.Zero = -0.25*pi;
minitaurParams.Sensing.Encoders.IVB.Zero = 0.5*pi;

% Electrical
minitaurParams.Electronics.Battery.MaxVoltage = 16.4; % [V]
minitaurParams.Electronics.Battery.NominalVoltage = 14.8; % [V]
minitaurParams.Electronics.Battery.MinVoltage = 12.4; % [V]

% BLDC Motor Model (all motors assumed identical)
minitaurParams.Actuation.Motors.RPMperVolt = 100; % [RPM/V]
minitaurParams.Actuation.Motors.Kv = 1/(minitaurParams.Actuation.Motors.RPMperVolt/60*2*pi); % [V*s / rad]
minitaurParams.Actuation.Motors.Kt = minitaurParams.Actuation.Motors.Kv; % [N*m / A]
minitaurParams.Actuation.Motors.R = 0.186; % [Ohm]
minitaurParams.Actuation.Motors.TorqueSat =  ...
    minitaurParams.Actuation.Motors.Kt * minitaurParams.Electronics.Battery.NominalVoltage / minitaurParams.Actuation.Motors.R;
minitaurParams.Actuation.Motors.TimeConst = 5e-3;

% Minitaur Mechanism (Internal) Friction (all legs assumed identical)
minitaurParams.Friction.KneeJoint.EffRadius = 3e-3;
minitaurParams.Friction.KneeJoint.VelThresh = 1e-1;
minitaurParams.Friction.KneeJoint.MuK = 0.1;
minitaurParams.Friction.KneeJoint.MuS = 0.2;
minitaurParams.Friction.KneeJoint.FricBandwidth = 100;

%% Environment

% Foot Contact Model
envParams.Ground.Width = 10;
envParams.Ground.Length = 100;
envParams.Ground.FrameDepth = 0.5;
envParams.Contact.FootContactRadius = 7.5e-3;

% These may be worth adjusting
envParams.Contact.Stiffness = 1e4;
envParams.Contact.Damping = 1e3;
envParams.Contact.MuK = 0.75;
envParams.Contact.MuS = 1;
envParams.Contact.VelThresh = 1e-2;


%% Controls and Trajectory Planning

controlParams.jointPID.P = 6;
controlParams.jointPID.I = .1;
controlParams.jointPID.D = 0.07;
controlParams.jointPID.N = 1000;

controlParams.CPG.ForeRearLag = 0.5*pi;
controlParams.CPG.Period = 1;
controlParams.CPG.LRSyncFlag = 0;

controlParams.FootImpedanceControl.r0 = -minitaurParams.Kinematics.L2;
controlParams.FootImpedanceControl.rx = 0.4*minitaurParams.Kinematics.L1;
controlParams.FootImpedanceControl.ry = 0.4*minitaurParams.Kinematics.L1;
controlParams.FootImpedanceControl.thetaTilt = 0;

% controlParams.FootTrajPlanner
% controlParams.CentralPatternGen   

%% Initial Conditions

% Initial Actuator Configurations
IC.Minitaur.IAq = -pi/4;
IC.Minitaur.IAqDot = 0;

IC.Minitaur.IBq = pi/4;
IC.Minitaur.IBqDot = 0;

IC.Minitaur.IIAq = -pi/4;
IC.Minitaur.IIAqDot = 0;

IC.Minitaur.IIBq = pi/4;
IC.Minitaur.IIBqDot = 0;

IC.Minitaur.IIIAq = -pi/4;
IC.Minitaur.IIIAqDot = 0;

IC.Minitaur.IIIBq = pi/4;
IC.Minitaur.IIIBqDot = 0;

IC.Minitaur.IVAq = -pi/4;
IC.Minitaur.IVAqDot = 0;

IC.Minitaur.IVBq = pi/4;
IC.Minitaur.IVBqDot = 0;

IC.Minitaur.ToeJointR = pi/2;
IC.Minitaur.ToeJointL = -pi/2;

% Initial Minitaur Body Pose
IC.Minitaur.Body.x = 0;
IC.Minitaur.Body.y = -envParams.Ground.Length/2 + 2;
IC.Minitaur.Body.z = envParams.Ground.FrameDepth/2+minitaurParams.Kinematics.L1+minitaurParams.Kinematics.L2+0.15;
IC.Minitaur.Body.xDot = 0;
IC.Minitaur.Body.yDot = 0;
IC.Minitaur.Body.zDot = 0;

IC.Minitaur.Body.RotXZX = [0 pi pi/2];  % [rad] (world frame)
IC.Minitaur.Body.w = [0 0 0]; % [rad/s] (world frame)

%% Model physical data
minitaur_model_data;

%% Turn everything into Simulink.Parameter objects
IC = Simulink.Parameter(IC);
controlParams = Simulink.Parameter(controlParams);
envParams = Simulink.Parameter(envParams);

minitaurParams.RigidTransform = rmfield(minitaurParams.RigidTransform, 'ID');
minitaurParams.Solid = rmfield(minitaurParams.Solid, 'ID');
minitaurParams.RevoluteJoint = rmfield(minitaurParams.RevoluteJoint, 'ID');
minitaurParams = Simulink.Parameter(minitaurParams);
