{
  extensions = [
    "cb7"
    "cbr"
    "cbt"
    "cbz"
    "djv"
    "djvu"
    "epub"
    "eps"
    "fb2"
    "mobi"
    "oxps"
    "pdf"
    "ps"
    "xps"
  ];

  handlers = [
    {
      desktop = "org.pwmt.zathura-pdf-mupdf.desktop";
      mimeTypes = [
        "application/epub+zip"
        "application/oxps"
        "application/pdf"
        "application/vnd.ms-xpsdocument"
        "application/x-fictionbook"
        "application/x-fictionbook+xml"
        "application/x-mobipocket-ebook"
      ];
    }
    {
      desktop = "org.pwmt.zathura-djvu.desktop";
      mimeTypes = [
        "image/vnd.djvu"
        "image/vnd.djvu+multipage"
      ];
    }
    {
      desktop = "org.pwmt.zathura-ps.desktop";
      mimeTypes = [
        "application/eps"
        "application/postscript"
        "application/x-eps"
        "image/eps"
        "image/x-eps"
      ];
    }
    {
      desktop = "org.pwmt.zathura-cb.desktop";
      mimeTypes = [
        "application/vnd.comicbook+zip"
        "application/vnd.comicbook-rar"
        "application/x-cb7"
        "application/x-cbr"
        "application/x-cbt"
        "application/x-cbz"
      ];
    }
  ];
}
