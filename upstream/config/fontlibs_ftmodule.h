/* The FreeType modules this repository builds: TrueType and CFF fonts (also in OpenType and collection files), the auto-hinter, the smooth
 * (anti-aliased) rasterizer. No Type 1, bitmap-only formats, SDF, SVG, or monochrome rasterizer. Used through
 * -DFT_CONFIG_MODULES_H=<fontlibs_ftmodule.h>. */
FT_USE_MODULE( FT_Module_Class, autofit_module_class )
FT_USE_MODULE( FT_Driver_ClassRec, tt_driver_class )
FT_USE_MODULE( FT_Driver_ClassRec, cff_driver_class )
FT_USE_MODULE( FT_Module_Class, psaux_module_class )
FT_USE_MODULE( FT_Module_Class, psnames_module_class )
FT_USE_MODULE( FT_Module_Class, pshinter_module_class )
FT_USE_MODULE( FT_Module_Class, sfnt_module_class )
FT_USE_MODULE( FT_Renderer_Class, ft_smooth_renderer_class )
