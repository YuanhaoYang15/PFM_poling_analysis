function designRow = get_design_row(meta, designID)
%GET_DESIGN_ROW Return one row from designs table.

designID = string(designID);
idx = meta.designs.designID == designID;

if ~any(idx)
    error('Design ID %s is not found in designs table.', designID);
end

designRow = meta.designs(find(idx, 1, 'first'), :);

end
