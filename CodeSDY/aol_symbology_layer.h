/*********************************************************
 **
 ** File  aol_symbology_layer.h
 **
 ** Specification File:  F:\TestPrj\TestScade\specification.sgfx
 **
 ** Automatically generated by SCADE Display KCG
 ** Version 6.6.4b (build i9)
 **
 ** Date of generation: 2018-01-27T10:54:10
 ** Command line: ScadeDisplayKCG.exe -outdir F:\TestPrj\TestScade\kcg -texturemax 1024 F:\TestPrj\TestScade\specification.sgfx
 *********************************************************/

#ifndef AOL_SYMBOLOGY_LAYER_H
#define AOL_SYMBOLOGY_LAYER_H

#include "sgl_types.h"


/* Accessors */

/* Context type */
typedef struct aol_typ_symbology_layer_ {
  SGLbool _empty_struct_;
} aol_typ_symbology_layer;

/* Associated functions */
extern void aol_symbology_layer_init(aol_typ_symbology_layer *pContext);
extern void aol_symbology_layer_predraw(aol_typ_symbology_layer *pContext);
extern void aol_symbology_layer_draw(aol_typ_symbology_layer *pContext, SGLint32 pPriority);

#endif /* AOL_SYMBOLOGY_LAYER_H */

/*********************************************************
 ** End of file
 ** End of generation: 2018-01-27T10:54:10
 *********************************************************/

