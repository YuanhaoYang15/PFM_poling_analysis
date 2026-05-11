function data = preprocess_pfm_text_file(filePath, cfg)
%PREPROCESS_PFM_TEXT_FILE Convert a raw PFM txt/csv/dat file to X/Y/phase matrices.
%
% For this project, the default reader is the proven NanoScope ASCII reader
% migrated from the old working script. It does NOT guess xyz/matrix/flat
% formats. It directly parses the NanoScope header, column names, image size,
% scan size, and reshapes the exported channels.

reader = 'nanoscope_legacy';
if isfield(cfg, 'preprocess') && isfield(cfg.preprocess, 'reader') && ...
        ~isempty(cfg.preprocess.reader)
    reader = cfg.preprocess.reader;
end

switch lower(reader)
    case {'nanoscope_legacy', 'legacy', 'nanoscope'}
        [D, info, raw] = read_pfm_txt_nanoscope_legacy(filePath, cfg);

        phaseField = 'LS_PR_Phase';
        if isfield(cfg, 'preprocess') && isfield(cfg.preprocess, 'phaseField') && ...
                ~isempty(cfg.preprocess.phaseField)
            phaseField = cfg.preprocess.phaseField;
        end

        if ~isfield(D, phaseField)
            % Try to find a reasonable phase field automatically.
            fn = fieldnames(D);
            score = zeros(numel(fn), 1);
            for ii = 1:numel(fn)
                nm = lower(fn{ii});
                if contains(nm, 'phase'), score(ii) = score(ii) + 10; end
                if contains(nm, 'ls_pr'), score(ii) = score(ii) + 5; end
                if contains(nm, 'pr'),    score(ii) = score(ii) + 2; end
            end
            [bestScore, idx] = max(score);
            if bestScore <= 0
                fprintf('Available fields:\n');
                disp(fn);
                error('Cannot find phase field "%s". Set cfg.preprocess.phaseField.', phaseField);
            end
            phaseField = fn{idx};
            warning('Requested phase field not found. Using "%s" instead.', phaseField);
        end

        phase = D.(phaseField);

        % Keep the old working coordinate convention.
        x_um = linspace(0, info.scanX_um, info.nx);
        y_um = linspace(0, info.scanY_um, info.ny);
        [X, Y] = meshgrid(x_um, y_um);

        phase = convert_and_wrap_phase(phase, cfg);

        data = struct();
        data.X = X;
        data.Y = Y;
        data.phase = phase;
        data.sourceFile = filePath;
        data.sourceType = 'nanoscope_legacy_txt';
        data.info = info;
        data.raw = raw;
        data.channels = D;
        data.phaseField = phaseField;

        fprintf('PFM phase field: %s\n', phaseField);
        fprintf('Phase range after wrapping: %.4g to %.4g deg\n', ...
            min(phase(:), [], 'omitnan'), max(phase(:), [], 'omitnan'));

    otherwise
        error(['Unknown cfg.preprocess.reader = "%s".\n', ...
               'Use cfg.preprocess.reader = ''nanoscope_legacy'';'], reader);
end

end
