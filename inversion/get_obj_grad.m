
function [f,g] = get_obj_grad(x)
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% user input
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % type = 'source';
    type = 'structure';

    measurement = 3;
    % 1 = 'log_amplitude_ratio';
    % 2 = 'amplitude_difference';
    % 3 = 'waveform_difference';
    % 4 = 'cc_time_shift';
    
    % load array with reference stations and data
    load('../output/interferometry/array_4_ref.mat');
    load('../output/interferometry/data_4_ref_structure_slow.mat');
    
    % design filter for smoothing of kernel
    myfilter = fspecial('gaussian',[40 40], 20);
    
 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calculate misfit and gradient
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
    
    % initialize variables
    path(path,genpath('../'))
    [~,~,nx,nz,~,~,~,~] = input_parameters();
   
    % initialize kernel structures
    if( strcmp(type,'source') )
        source_dist = x;
        mu = 4.8e10*ones(nx*nz,1);
        
        f_sample = input_interferometry();
        K_all = zeros(nx, nz, length(f_sample));
        
    elseif( strcmp(type,'structure') )
        source_dist = ones(nx*nz,1);
        mu = 4.8e10 * (1+x);
        
        K_all = zeros(nx, nz);
    end
    
    
    % loop over reference stations
    f = 0;
    parfor i = 1:size(ref_stat,1)
        
        
        % each reference station will act as a source once
        src = ref_stat(i,:);
        rec = array( find( ~ismember(array, src, 'rows') ) ,:);
        
        % calculate Green function
        % G_2 = load(['../output/interferometry/G_2_' num2str(i) '.mat']);
        [G_2] = run_forward_green_fast_mex(mu, src);       
        
        % calculate correlation
        [c_it, t, C_2, C_2_dxv, C_2_dzv] = run_forward_correlation_fast_mex(G_2, source_dist, mu, rec);
        
        
        % calculate misfit and adjoint source function
        indices = (i-1)*size(rec,1) + 1 : i*size(rec,1);
        switch measurement
            case 1
                [f_n,adstf] = make_adjoint_sources_inversion( c_it, c_data(indices,:), t, 'dis', 'log_amplitude_ratio', src, rec );
            case 2
                [f_n,adstf] = make_adjoint_sources_inversion( c_it, c_data(indices,:), t, 'dis', 'amplitude_difference', src, rec );
            case 3
                [f_n,adstf] = make_adjoint_sources_inversion( c_it, c_data(indices,:), t, 'dis', 'waveform_difference', src, rec );
            case 4
                [f_n,adstf] = make_adjoint_sources_inversion( c_it, c_data(indices,:), t, 'dis', 'cc_time_shift', src, rec );
            otherwise
                error('\nspecify correct measurement!\n\n')
        end
        
        
        if( strcmp(type,'source') )            
            % calculate source kernel
            [~,~,K_i] = run_noise_source_kernel_fast_mex(G_2, mu, adstf, rec);
                
        elseif( strcmp(type,'structure') )            
            % calculate structure kernel
            [~,~,~,K_i] = run_noise_structure_kernel_fast_mex(C_2, C_2_dxv, C_2_dzv, mu, adstf, rec);
        
        end
        
        
        % sum up kernels
        K_all = K_all + K_i;
        
        % sum up misfits
        f = f + f_n;
        
        
    end
    
    fprintf('misfit: %f\n',f)
    
    % smooth final kernel
    if( strcmp(type,'source') )
        K_all = sum( K_all(:,:,8:33),3 );
    end
    
    K_all = imfilter( K_all, myfilter, 'symmetric' );
    g = 4.8e10 * reshape( K_all, [], 1 );

    
    
end
