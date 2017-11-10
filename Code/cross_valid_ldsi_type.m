%
% err = cross_valid_ldsi(Y, m_upper, n_fold, varargin)
%
% Cross validation of ldsi fitting result
%
% Inputs:
%
% Y       -- n x (T x K) observation data matrix
% K       -- number of trials
% n       -- dimension of observation
% T       -- length of obervations in each trial 
% m_upper -- dimension of state variable (from 1 to m_upper)
% n_fold  --
% cyc -- maximum number of cycles of EM (default: 1000)
% tol -- termination tolerance (% change in likelihood) (default: 0.01%)
%
% Output:
% 
% err  -- mean estimation error across n fold
%
%
% Model:
%
%             y(k,t) = Ph.C * x(k,t) + Ph.D * y(k,s) + Ph.d(k) + v(k,t)
%             x(k,t) = Ph.A * x(k,s) + Ph.bt(k,s) + w(k,s)
%             s      = t - 1
%        where
%             v ~ N(0,R)
%             w ~ N(0,Q)
%             x(k,1) ~ N(pi,Q0) (for any k)
%
%        S.T.
%             bt' * inv(Q) * bt = T
%        with
%             fixed lambda (regularizor)
%
%
% This is main function that handles cross-validation of n fold method.
%
% Ver: 1.0 
%
% @ 2014 Ziqiang Wei
% weiz@janelia.hhmi.org
% 
% 


function err = cross_valid_ldsi_type(Y, m_upper, n_fold, timePoints, trial_type, varargin)

    [n, T, K]  = size(Y);
    if m_upper > n
        disp ('Dimension of interal state variable is no less than that of observation.');
        disp ('Default dimension in cross-validation will be used instead.');
        m_upper  = n;
    end
    
    
    K_per_fold  = floor(K/n_fold);
    
    err         = zeros(m_upper,n_fold);
    
    for m = 1: m_upper
        disp(['Now running for xDim = ',num2str(m),'....']);
        for curr_fold = 1: n_fold
            disp (['Running code on fold ',num2str(curr_fold),'....']);
            test_list  = ((curr_fold-1)*K_per_fold+1):(curr_fold*K_per_fold);
            train_list = 1:K;
            train_list (test_list) = [];
            Y_test     = Y(:,:,test_list);
            Y_train    = Y(:,:,train_list);
            Type_test  = trial_type(test_list);
            Type_train = trial_type(train_list);
            is_fit     = false;
            while ~is_fit
                try
                    PhA        = lds(Y_train(:,:,Type_train), m, 'timePoint', timePoints, varargin{:});
                    is_fit     = true;
                catch
                    is_fit     = false;
                end
            end
            
            is_fit     = false;
            while ~is_fit
                try
                    PhB        = lds(Y_train(:,:,~Type_train), m, 'timePoint', timePoints, varargin{:});
                    is_fit     = true;
                catch
                    is_fit     = false;
                end
            end
            
            y_est      = nan(size(Y_test));
                
%             curr_err   = 0;
%             for n_task = 1:K_per_fold
%                 [n_err, ~] = loo (squeeze(Y_test(:,:,n_task)), Ph);
%                 curr_err      = curr_err + n_err;
%             end            
            [~, y_est(:,:,Type_test), ~] = loo (Y_test(:,:,Type_test), PhA, [0, timePoints, T]);
            [~, y_est(:,:,~Type_test), ~] = loo (Y_test(:,:,~Type_test), PhB, [0, timePoints, T]);
            
            curr_err   = sum((Y_test(:) - y_est(:)).^2);
            
            mean_Y     = mean(mean(Y_train, 3), 2);
            Y_prime    = remove_mean(Y_test, mean_Y);
            
            rand_y     = sum(Y_prime(:).^2);
            
            err (m, curr_fold)    = curr_err/rand_y;
        end        
    end