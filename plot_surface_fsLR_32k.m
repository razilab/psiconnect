function [fig,varargout] = plot_surface_fsLR_32k(data_to_plot,hemi,mesh,show_medial_wall,clims)
% Plot data on fsLR_32k cortical surface

%requires BrainEigenmodes: https://github.com/james-pang/BrainEigenmodes

template        = "fsLR_32k";

% Load relevant repository MATLAB functions
dir_base        = "/path/to/BrainEigenmodes";
dir_data        = fullfile(dir_base,"data");
dir_templates   = fullfile(dir_data,"template_surfaces_volumes");
dir_functions   = fullfile(dir_base,"functions_matlab");
addpath(genpath(dir_functions));
% addpath(genpath(dir_templates));

% convert to string format
hemi            = string(hemi);
mesh            = string(mesh);

% Load surface file
f_surf          = fullfile(dir_templates,template+"_"+mesh+"-"+hemi+".vtk");
if ~isfile(f_surf)
    error("Surface file not found: %s",f_surf)
end

[vert, faces]   = read_vtk(f_surf);
surf.vertices   = vert';
surf.faces      = faces';

% Load cortex mask
f_cort_mask     = fullfile(dir_templates,template+"_cortex-"+hemi+"_mask.txt");
if ~isfile(f_surf)
    error("Cortex mask file not found: %s",f_cort_mask)
end
cortex          = dlmread(f_cort_mask);

% Visualize                      
surf_to_plot    = surf;
medial_wall     = find(cortex==0);

% with medial wall view
varargout = cell(1,3);
if exist("clims","var")
    [fig,varargout{1},varargout{2},varargout{3}] = draw_surface_bluewhitered_dull(surf_to_plot,data_to_plot,...
                        hemi,medial_wall,show_medial_wall,clims);
else
    [fig,varargout{1},varargout{2},varargout{3}] = draw_surface_bluewhitered_dull(surf_to_plot,data_to_plot,...
                        hemi,medial_wall,show_medial_wall);
end
end
