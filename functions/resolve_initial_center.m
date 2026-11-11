function center0 = resolve_initial_center(cfg, scanCfg)
%RESOLVE_INITIAL_CENTER Resolve initial center from scanCfg or picked-center files.
%
% Priority: scan metadata, batch picked centers, legacy device picked centers.

[center0, found] = find_initial_center(cfg, scanCfg);
if found
    return;
end

error(['Initial center is not set for device %s scan %d.\n', ...
       'Run main_pick_initial_centers_for_batch first, or set centerX_um/centerY_um in scans metadata.'], ...
       cfg.deviceName, scanCfg.scanID);

end
