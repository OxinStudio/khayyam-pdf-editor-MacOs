#import "MuPDFBridge.h"
#import <mupdf/fitz.h>
#import <mupdf/pdf.h>

// ── Helpers ───────────────────────────────────────────────────────────────────

static NSError *mupdfError(fz_context *ctx, const char *msg) {
    return [NSError errorWithDomain:@"MuPDF"
                               code:-1
                           userInfo:@{NSLocalizedDescriptionKey: @(msg)}];
}

/// Convert a MuPDF fz_rect (top-left origin, y-down) to a CGRect in
/// PDF coordinate space (bottom-left origin, y-up) given the page height.
static CGRect fzRectToCGRect(fz_rect r, float pageHeight) {
    return CGRectMake(r.x0,
                      pageHeight - r.y1,
                      r.x1 - r.x0,
                      r.y1 - r.y0);
}

/// Convert a CGRect in PDF coordinate space back to fz_rect.
static fz_rect cgRectToFzRect(CGRect r, float pageHeight) {
    return fz_make_rect((float)r.origin.x,
                        (float)(pageHeight - (r.origin.y + r.size.height)),
                        (float)(r.origin.x + r.size.width),
                        (float)(pageHeight - r.origin.y));
}

// ── MuPDFTextChar ─────────────────────────────────────────────────────────────

@implementation MuPDFTextChar
@end

// ── MuPDFTextLine ─────────────────────────────────────────────────────────────

@implementation MuPDFTextLine
@end

// ── MuPDFTextBlock ────────────────────────────────────────────────────────────

@implementation MuPDFTextBlock
@end

// ── PDFMuPDFBridge ────────────────────────────────────────────────────────────

@implementation PDFMuPDFBridge {
    fz_context   *_ctx;
    fz_document  *_doc;
    pdf_document *_pdfdoc;
}

- (nullable instancetype)initWithURL:(NSURL *)url error:(NSError **)error {
    self = [super init];
    if (!self) return nil;

    _ctx = fz_new_context(NULL, NULL, FZ_STORE_UNLIMITED);
    if (!_ctx) {
        if (error) *error = mupdfError(nil, "Failed to create MuPDF context");
        return nil;
    }

    fz_register_document_handlers(_ctx);

    int failed = 0;
    fz_try(_ctx) {
        _doc = fz_open_document(_ctx, url.fileSystemRepresentation);
        _pdfdoc = pdf_document_from_fz_document(_ctx, _doc);
    }
    fz_catch(_ctx) {
        failed = 1;
    }

    if (failed || !_doc) {
        if (error) *error = mupdfError(_ctx, "Could not open PDF");
        fz_drop_context(_ctx);
        _ctx = nil;
        return nil;
    }

    return self;
}

- (int)pageCount {
    if (!_ctx || !_doc) return 0;
    int count = 0;
    fz_try(_ctx) { count = fz_count_pages(_ctx, _doc); }
    fz_catch(_ctx) { count = 0; }
    return count;
}

- (NSArray<MuPDFTextBlock *> *)textBlocksOnPage:(int)pageIndex {
    NSMutableArray<MuPDFTextBlock *> *result = [NSMutableArray array];
    if (!_ctx || !_doc) return result;

    fz_page       *page     = NULL;
    fz_stext_page *textPage = NULL;

    fz_try(_ctx) {
        page = fz_load_page(_ctx, _doc, pageIndex);

        // Get page bounds (PDF coordinate space, y-up).
        fz_rect mediaBox = fz_bound_page(_ctx, page);
        float pageHeight = mediaBox.y1 - mediaBox.y0;

        fz_stext_options opts = {};
        opts.flags = FZ_STEXT_PRESERVE_SPANS | FZ_STEXT_PRESERVE_WHITESPACE;
        textPage = fz_new_stext_page_from_page(_ctx, page, &opts);

        for (fz_stext_block *block = textPage->first_block; block; block = block->next) {
            if (block->type != FZ_STEXT_BLOCK_TEXT) continue;

            MuPDFTextBlock *outBlock = [[MuPDFTextBlock alloc] init];
            outBlock.pageIndex = pageIndex;
            outBlock.bounds    = fzRectToCGRect(block->bbox, pageHeight);

            NSMutableArray<MuPDFTextLine *> *outLines = [NSMutableArray array];
            NSMutableString *blockText = [NSMutableString string];
            float dominantSize = 0;
            int charCount = 0;

            for (fz_stext_line *line = block->u.t.first_line; line; line = line->next) {
                MuPDFTextLine *outLine = [[MuPDFTextLine alloc] init];
                outLine.bounds = fzRectToCGRect(line->bbox, pageHeight);

                NSMutableArray<MuPDFTextChar *> *outChars = [NSMutableArray array];
                NSMutableString *lineText = [NSMutableString string];

                for (fz_stext_char *ch = line->first_char; ch; ch = ch->next) {
                    // Build char bounds from the quad origin
                    fz_rect charRect = fz_rect_from_quad(ch->quad);
                    MuPDFTextChar *outChar = [[MuPDFTextChar alloc] init];
                    outChar.character = (unichar)ch->c;
                    outChar.bounds    = fzRectToCGRect(charRect, pageHeight);
                    outChar.fontSize  = ch->size;
                    [outChars addObject:outChar];

                    unichar c = (unichar)ch->c;
                    [lineText appendString:[NSString stringWithCharacters:&c length:1]];

                    dominantSize += ch->size;
                    charCount++;
                }

                outLine.chars = [outChars copy];
                outLine.text  = [lineText copy];
                [outLines addObject:outLine];
                [blockText appendString:lineText];
                if (line->next) [blockText appendString:@"\n"];
            }

            outBlock.lines             = [outLines copy];
            outBlock.text              = [blockText copy];
            outBlock.dominantFontSize  = charCount > 0 ? dominantSize / charCount : 12.0f;
            [result addObject:outBlock];
        }
    }
    fz_always(_ctx) {
        if (textPage) fz_drop_stext_page(_ctx, textPage);
        if (page)     fz_drop_page(_ctx, page);
    }
    fz_catch(_ctx) {
        // Return partial results
    }

    return [result copy];
}

- (BOOL)redactRect:(CGRect)rect onPage:(int)pageIndex error:(NSError **)error {
    if (!_ctx || !_pdfdoc) {
        if (error) *error = mupdfError(_ctx, "No document loaded");
        return NO;
    }

    __block BOOL success = NO;
    fz_page  *page    = NULL;
    pdf_page *pdfPage = NULL;

    fz_try(_ctx) {
        page    = fz_load_page(_ctx, _doc, pageIndex);
        pdfPage = pdf_page_from_fz_page(_ctx, page);

        fz_rect mediaBox  = fz_bound_page(_ctx, page);
        float pageHeight  = mediaBox.y1 - mediaBox.y0;

        fz_rect fzRect = cgRectToFzRect(rect, pageHeight);

        // pdf_add_redact_annot was removed in MuPDF 1.25+.
        // Use the lower-level API: create a Redact annotation, set its rect,
        // then call pdf_redact_page to apply it (removes the underlying content).
        pdf_annot *annot = pdf_create_annot(_ctx, pdfPage, PDF_ANNOT_REDACT);
        pdf_set_annot_rect(_ctx, annot, fzRect);

        // White interior fill so the redacted area shows as blank
        float white[3] = {1.0f, 1.0f, 1.0f};
        pdf_set_annot_interior_color(_ctx, annot, 3, white);

        pdf_update_annot(_ctx, annot);
        pdf_drop_annot(_ctx, annot);

        // Apply: strips underlying content stream operators in the rect
        pdf_redact_options ropts   = {};
        ropts.black_boxes          = 0;
        ropts.image_method         = PDF_REDACT_IMAGE_NONE;
        pdf_redact_page(_ctx, _pdfdoc, pdfPage, &ropts);

        success = YES;
    }
    fz_always(_ctx) {
        if (page) fz_drop_page(_ctx, page);
    }
    fz_catch(_ctx) {
        if (error) *error = mupdfError(_ctx, fz_caught_message(_ctx));
        success = NO;
    }

    return success;
}

- (BOOL)saveToURL:(NSURL *)url error:(NSError **)error {
    if (!_ctx || !_pdfdoc) {
        if (error) *error = mupdfError(_ctx, "No document loaded");
        return NO;
    }

    BOOL success = NO;
    fz_try(_ctx) {
        pdf_write_options opts = pdf_default_write_options;
        opts.do_incremental = 0;   // full rewrite for cleanliness
        opts.do_garbage     = 4;   // compact + deduplicate
        opts.do_compress    = 1;
        pdf_save_document(_ctx, _pdfdoc, url.fileSystemRepresentation, &opts);
        success = YES;
    }
    fz_catch(_ctx) {
        if (error) *error = mupdfError(_ctx, fz_caught_message(_ctx));
        success = NO;
    }
    return success;
}

- (void)dealloc {
    if (_doc && _ctx)  fz_drop_document(_ctx, _doc);
    if (_ctx)          fz_drop_context(_ctx);
}

@end
