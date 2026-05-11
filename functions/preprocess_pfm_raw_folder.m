function data = preprocess_pfm_raw_folder(folderPath, cfg, scanCfg)
%PREPROCESS_PFM_RAW_FOLDER Find and preprocess the PFM phase txt file in a raw folder.

phaseFile = find_phase_file_in_folder(folderPath, cfg, scanCfg);
fprintf('Phase file selected: %s\n', phaseFile);

data = preprocess_pfm_text_file(phaseFile, cfg);
data.sourceFolder = folderPath;

end

function phaseFile = find_phase_file_in_folder(folderPath, cfg, scanCfg)
    pattern = getfield_or(scanCfg, 'phaseFilePattern', '');

    if ~isempty(pattern)
        files = dir(fullfile(folderPath, pattern));
        files = files(~[files.isdir]);
        if ~isempty(files)
            phaseFile = fullfile(folderPath, files(1).name);
            return;
        end
    end

    exts = {'*.txt', '*.csv', '*.dat'};
    allFiles = [];
    for ii = 1:numel(exts)
        allFiles = [allFiles; dir(fullfile(folderPath, exts{ii}))]; %#ok<AGROW>
    end
    allFiles = allFiles(~[allFiles.isdir]);

    if isempty(allFiles)
        error('No txt/csv/dat files found in folder: %s', folderPath);
    end

    keywords = cfg.preprocess.phaseFileKeywords;
    score = zeros(numel(allFiles), 1);

    for ii = 1:numel(allFiles)
        nm = lower(allFiles(ii).name);
        for kk = 1:numel(keywords)
            if contains(nm, lower(keywords{kk}))
                score(ii) = score(ii) + 1;
            end
        end

        % Avoid obvious non-phase channels when possible.
        if contains(nm, 'height'); score(ii) = score(ii) - 2; end
        if contains(nm, 'amp');    score(ii) = score(ii) - 1; end
        if contains(nm, 'amplitude'); score(ii) = score(ii) - 1; end
        if contains(nm, 'error');  score(ii) = score(ii) - 1; end
    end

    [bestScore, idx] = max(score);
    if bestScore <= 0
        fprintf('Files found in folder:\n');
        for ii = 1:numel(allFiles)
            fprintf('  %s\n', allFiles(ii).name);
        end
        error(['Cannot automatically identify phase file in folder.\n', ...
               'Set scanCfg.phaseFilePattern, e.g. ''*Phase*.txt''.']);
    end

    phaseFile = fullfile(folderPath, allFiles(idx).name);
end
