%% Transform 2D Cross-Spectral Density Maps into 3D Tensors
clear

%% Configuration Root Path
dir_base = "/path/to/PsiConnect/folder";
dir_csd  = fullfile(dir_base, "derivatives", "EEG", "cleaned_RELAX", "FieldTrip_format", "CSD");

% Verify directory exists
if ~exist(dir_csd, 'dir')
    error("Configured CSD data directory does not exist: %s", dir_csd);
end

% Read existing files within the folder target
files = dir(fullfile(dir_csd, "sub-PC*CSD.mat"));
file_names = string({files.name});

%% Processing Transformation Vector-to-Matrix
for f = file_names
    fprintf("Transforming CSD for file: %s\n", f);
    load(fullfile(dir_csd, f));
    
    CSD_2D      = CSD.crsspctrm;
    pow_spectr  = CSD.powspctrm;
    
    ch_n        = length(CSD.label);
    freq_n      = length(CSD.freq);
    ch_labels   = CSD.label;
    ch_freq     = CSD.freq;
    
    clear CSD;
    
    % Initialize 3D tensor
    CSD = NaN(ch_n, ch_n, freq_n);
    
    % Reconstruct matrices across frequencies
    for freq = 1:freq_n
        index = 1;
        for col = 1:ch_n
            % Diagonal components hold the absolute power spectrum
            CSD(col, col, freq) = pow_spectr(col, freq);
            for row = col+1:ch_n
                % Reconstitute elements based on cross-spectral parameters
                CSD(row, col, freq) = CSD_2D(index, freq);
                CSD(col, row, freq) = conj(CSD_2D(index, freq)); % Complex conjugate transpose
                index = index + 1;
            end
        end
    end
    
    % Validation check to guarantee complete matrices were parsed
    assert(all(~isnan(CSD(:))), "Error: Missing metrics or NaN values detected in constructed CSD.");
    
    % Save data using clear tracking names
    f_out = strrep(f, ".mat", "3D.mat");
    save(fullfile(dir_csd, f_out), "CSD", "ch_labels", "ch_freq");
end

%% Plot Verification Figure
figure('Color', 'w');
plot(log(ch_freq), log(abs(CSD_2D')));
title("Log-Log Absolute Value of 2D CSD");
xlabel("Log Frequency");
ylabel("Log Magnitude");
grid on;