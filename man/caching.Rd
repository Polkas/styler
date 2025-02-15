% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ui-caching.R
\name{caching}
\alias{caching}
\title{Remember the past to be quicker in the future}
\description{
Caching makes styler faster on repeated styling and is shared across all APIs
(e.g. \code{style_text()} and Addin).
That means if you style code that already complies to a
style guide and you have previously styled that code, it will be quicker.
}
\section{Manage the cache}{

See \code{\link[=cache_info]{cache_info()}},\code{\link[=cache_activate]{cache_activate()}} or \code{\link[=cache_clear]{cache_clear()}} for utilities to
manage the cache. You can deactivate it altogether with \code{\link[=cache_deactivate]{cache_deactivate()}}.
Since we leverage \code{{R.cache}} to manage the cache, you can also use any
\code{{R.cache}} functionality to manipulate it.

In some cases, you want to use a non-standard cache location. In
that situation, you can set the path to the cache with the R option
\code{R.cache.rootPath} or the environment variable \code{R_CACHE_ROOTPATH} to an
existent path before you call the styler API.
}

\section{Invalidation}{

The cache is specific to a version of styler by default, because different
versions potentially format code differently. This means after upgrading
styler or a style guide you use, the cache will be re-built.
}

\section{Mechanism and size}{

The cache works by storing hashed output code as a whole and by expression,
which is why it takes zero space on disk (the cache is a directory with
empty files which have the hash of output code as name).
}

\section{Using a cache for styler in CI/CD}{

If you want to set up caching in a CI/CD pipeline, we suggest to set the
\code{{R.cache}} root path to a directory for which you have the cache enabled.
This can often be set in config files of CI/CD tools, e.g. see the
\href{https://docs.travis-ci.com/user/caching}{Travis documentation on caching}.
}

\seealso{
Other cache managers: 
\code{\link{cache_activate}()},
\code{\link{cache_clear}()},
\code{\link{cache_info}()}
}
\concept{cache managers}
