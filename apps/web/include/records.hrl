-record(tinymce,        {?ELEMENT_BASE(element_tinymce), html="", script_url="static/tinymce/tinymce.min.js", theme="modern"}).
-record(feed_entry,     {?ELEMENT_BASE(product), entry}).
-record(feed_comment,   {?ELEMENT_BASE(product), comment}).
-record(feed_media,     {?ELEMENT_BASE(product), media, target, fid=0, cid=0, only_thumb}).
-record(product_figure, {?ELEMENT_BASE(product), product}).