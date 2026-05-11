function meta = read_batch_metadata(batchCfg)
%READ_BATCH_METADATA Read designs/devices/scans metadata CSV files.

assert(isfile(batchCfg.metadata.designsFile), 'Design metadata not found: %s', batchCfg.metadata.designsFile);
assert(isfile(batchCfg.metadata.devicesFile), 'Device metadata not found: %s', batchCfg.metadata.devicesFile);
assert(isfile(batchCfg.metadata.scansFile),   'Scan metadata not found: %s',   batchCfg.metadata.scansFile);

designs = readtable(batchCfg.metadata.designsFile, 'TextType', 'string');
devices = readtable(batchCfg.metadata.devicesFile, 'TextType', 'string');
scans   = readtable(batchCfg.metadata.scansFile,   'TextType', 'string');

designs.designID = string(designs.designID);
devices.deviceID = string(devices.deviceID);
devices.designID = string(devices.designID);
scans.deviceID   = string(scans.deviceID);
scans.rawName    = string(scans.rawName);

if ~ismember('phaseFilePattern', scans.Properties.VariableNames)
    scans.phaseFilePattern = strings(height(scans), 1);
else
    scans.phaseFilePattern = string(scans.phaseFilePattern);
end

if ~ismember('positionLabel', scans.Properties.VariableNames)
    scans.positionLabel = strings(height(scans), 1);
else
    scans.positionLabel = string(scans.positionLabel);
end

if ~ismember('notes', scans.Properties.VariableNames)
    scans.notes = strings(height(scans), 1);
else
    scans.notes = string(scans.notes);
end

if ~ismember('centerX_um', scans.Properties.VariableNames)
    scans.centerX_um = nan(height(scans), 1);
end
if ~ismember('centerY_um', scans.Properties.VariableNames)
    scans.centerY_um = nan(height(scans), 1);
end

meta = struct();
meta.designs = designs;
meta.devices = devices;
meta.scans = scans;

end
