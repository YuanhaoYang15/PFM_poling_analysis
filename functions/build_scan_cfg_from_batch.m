function [cfgScan, scanCfg] = build_scan_cfg_from_batch(batchCfg, deviceRow, scanRow, designRow)
%BUILD_SCAN_CFG_FROM_BATCH Build single-scan cfg and scanCfg from batch metadata.
%
% This function adapts the batch/device/design/scan table abstraction to the
% existing single-scan analysis functions.

deviceID = string(deviceRow.deviceID);
designID = string(deviceRow.designID);

cfgScan = batchCfg;

cfgScan.deviceName = char(deviceID);
cfgScan.currentDeviceID = char(deviceID);
cfgScan.currentDesignID = char(designID);

cfgScan.paths.processedData = fullfile(batchCfg.paths.processedRoot, char(deviceID));
cfgScan.paths.figures       = fullfile(batchCfg.paths.figureRoot,    char(deviceID));

if ~exist(cfgScan.paths.processedData, 'dir'); mkdir(cfgScan.paths.processedData); end
if ~exist(cfgScan.paths.figures, 'dir'); mkdir(cfgScan.paths.figures); end

% Design parameters.
cfgScan.design.R0 = get_numeric_table_value(designRow, 'R0_um', 30.0);
cfgScan.design.w  = get_numeric_table_value(designRow, 'w_um', 1.0);

cfgScan.design.periodRef.Rref = get_numeric_table_value(designRow, 'Rref_um', cfgScan.design.R0);
cfgScan.design.periodRef.LambdaRef = get_numeric_table_value(designRow, 'LambdaRef_um', 2.5);

% Radius analysis range.
cfgScan.radius.rMin = get_numeric_table_value(designRow, 'rMin_um', cfgScan.design.R0 - 2);
cfgScan.radius.rMax = get_numeric_table_value(designRow, 'rMax_um', cfgScan.design.R0 + 5);
cfgScan.radius.dr   = get_numeric_table_value(designRow, 'dr_um', 0.1);

% Optional scan-size information for matrix-only raw txt files.
sx = get_numeric_table_value(designRow, 'scanSizeX_um', NaN);
sy = get_numeric_table_value(designRow, 'scanSizeY_um', NaN);
if isfinite(sx) && isfinite(sy)
    cfgScan.preprocess.scanSizeUm = [sx, sy];
end

% Optional angular range override.
thetaMin = get_numeric_table_value(designRow, 'thetaMin_deg', NaN);
thetaMax = get_numeric_table_value(designRow, 'thetaMax_deg', NaN);
if isfinite(thetaMin) && isfinite(thetaMax)
    cfgScan.arc.thetaRange = [thetaMin, thetaMax] * pi/180;
end

% Build scanCfg.
scanCfg = struct();
scanCfg.scanID = double(scanRow.scanID);
scanCfg.rawName = get_text_table_value(scanRow, 'rawName', '');
scanCfg.fileName = scanCfg.rawName; % compatibility

scanCfg.phaseFilePattern = get_text_table_value(scanRow, 'phaseFilePattern', '*.txt');
scanCfg.positionLabel = get_text_table_value(scanRow, 'positionLabel', '');
scanCfg.notes = get_text_table_value(scanRow, 'notes', '');
scanCfg.deviceID = char(deviceID);
scanCfg.designID = char(designID);

cx = get_numeric_table_value(scanRow, 'centerX_um', NaN);
cy = get_numeric_table_value(scanRow, 'centerY_um', NaN);
if isfinite(cx) && isfinite(cy)
    scanCfg.centerInitial = [cx, cy];
else
    scanCfg.centerInitial = [];
end

end
