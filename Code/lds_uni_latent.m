%
% Ph = lds(Y, m, cyc, tol)
%
% Parameter estimation for linear dynamic system with external inputs
%
% Inputs:
%
% Y           -- n x T x K observation data set (a cell)
% K           -- number of trials
% n           -- dimension of observation
% Tk          -- length of obervations in each trial k
% m           -- dimension of state variable
% cyc         -- maximum number of cycles of EM (default: 1000)
% tol         -- termination tolerance (% change in likelihood) (default: 0.01%)
% timePoints  -- nt - 1 specific the time points for different processes:
%                like prestimulus, sample, delay and response
%
% Output Ph (struct) ->
% 
% Ph.A  -- state transition matrix
% Ph.Q  -- state noise covarince
% Ph.x0 -- initial state mean
% Ph.Q0 -- initial state covariance
% Ph.C  -- observation matrix
% Ph.R  -- observation covariance
% Ph.LL -- log likelihood
%
%
% Model:
%
%             y(k,t) = Ph.C * x(k,t) + v(k,t)
%             x(k,t) = Ph.A * x(k,s) + w(k,s)
%             s      = t - 1
%        where
%             v ~ N(0,R)
%             w ~ N(0,Q)
%             x(k,1) ~ N(pi,Q0) (for any k if prestimulus process is not
%                               included, otherwise pi = zeros, Q0 = eyes)
%
%
% This is main function that handles EM iterations until change of LL < tol
% or cyc step reaches maximum cyc value.
%
% @ 2014 Ziqiang Wei
% weiz@janelia.hhmi.org
% 
% 

function Ph = lds_uni_latent(Y, xDim, varargin)

    cyc       = 100;
    tol       = 0.0001;
    mean_type = 'stage_mean';
    yDim      = size(Y ,1);
    T         = size(Y, 2);
    K         = size(Y, 3);
    Y_train   = true(K,1);
    timePoint = [0, T];
    nt        = 1;
    is_fix_C  = false;
    is_fix_A  = false;
    
    nargs = length(varargin);
    if rem(nargs,2) ~= 0
        error('=========== Wrong number of parameters for E-step ======');
    end
    
    for n_args = 1:2:nargs
        switch varargin{n_args}
            case 'cyc'
                cyc       = varargin{n_args+1};
            case 'tol'
                tol       = varargin{n_args+1};
            case 'timePoint'
                timePoint = varargin{n_args+1};
                nt        = size(timePoint,2) + 1;
                timePoint = [0, timePoint, T]; %#ok<AGROW>
            case 'mean_type'
                mean_type = varargin{n_args+1};
            case 'Y_train'
                Y_train   = varargin{n_args+1};
            case 'is_fix_C'
                is_fix_C  = varargin{n_args+1};
            case 'is_fix_A'
                is_fix_A  = varargin{n_args+1};
            otherwise
                error(['=========== Unrecognized argument in E-step ', varargin{n_args}]);
        end
    end

    rng('shuffle');
    
    
    
    C     = nan  (yDim, xDim, nt);
    R     = zeros(yDim, yDim, nt);
    A     = zeros(xDim, xDim, nt);
    Q     = zeros  (xDim, xDim, nt);
    x0    = zeros(xDim,1);
    Q0    = eye(xDim,xDim);
    d     = nan  (yDim, nt);
    
    Yk    = nan  (size(Y));    
    
    for nt_now  =  1:nt
        Q(:, :, nt_now) = eye(xDim, xDim);
        
        switch upper(mean_type)
            case upper('constant_mean')
                Y_now          =  Y(:,(timePoint(nt_now)+1):timePoint(nt_now + 1),:);
                Y_s            =  Y(:,:,:);
                Y_all          =  reshape(Y_now, yDim, []);
                d(:, nt_now)   =  mean(reshape(Y_s, yDim, []), 2);
                Y_all          =  remove_mean(Y_all, d(:, nt_now));
            case upper('stage_mean')
                Y_now          =  Y(:,(timePoint(nt_now)+1):timePoint(nt_now + 1),:);
                Y_all          =  reshape(Y_now, yDim, []);
                d(:, nt_now)   =  mean(Y_all, 2);
                Y_all          =  remove_mean(Y_all, d(:, nt_now));
            case upper('timeVarying_mean')
                d              = mean(Y,3);
                Y              = bsxfun(@minus,Y,d);
                Y_now          = Y(:,(timePoint(nt_now)+1):timePoint(nt_now + 1),:);
                Y_all          = reshape(Y_now, yDim, []);
            case upper('no_mean')
                d              = 0;
                Y_now          =  Y(:,(timePoint(nt_now)+1):timePoint(nt_now + 1),:);
                Y_all          =  reshape(Y_now, yDim, []);
        end
        
        [Ct, Rt] = ffa(Y_all', xDim); 
        
        C(:,:,nt_now)  =  Ct;
        R(:,:,nt_now)  =  diag(Rt);
        
        Yk(:,(timePoint(nt_now)+1):timePoint(nt_now + 1),:) ...
                   =  reshape(Y_all, yDim, [], K);
    end
    
    % Run codes:

    Ph     = em_lds_uni_latent(Yk(:,:,Y_train), xDim, cyc, tol, C, R, A, Q, x0, Q0, timePoint, is_fix_C, is_fix_A);    
    Ph.d   = d;    
    Ph.Y   = Yk;