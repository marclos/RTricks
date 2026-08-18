\name{instructor_guide}
\alias{instructor_guide}
\alias{instructor-guide}
\title{Instructor Guide: Regional Climate Narratives}
\description{
Instructor-facing notes for the Regional Climate Narratives activity:
maintaining the package, building the student distribution zip,
publishing the handout, and (second half) pedagogical scaffolding for
turning the activity into a lecture. Students do not need this page.
Type \code{?instructor_guide} after loading the package to read it.
}
\details{

\strong{Naming convention.} Everything in this project uses one name in
two spellings: "Regional Climate Narratives" in prose and
"Regional_Climate_Narratives" in file and folder names. The single
forced exception is the R package itself, \pkg{RegionalClimateNarratives},
because R package names cannot contain underscores or spaces; this is
the name students type in \code{library()}.

\strong{How the pieces fit together:}

\tabular{ll}{
  Package source \tab \code{DESCRIPTION}, \code{R/}, \code{man/}; builds to a tar.gz \cr
  \code{Regional_Climate_Narratives_<ver>.tar.gz} \tab renamed build output; what students install \cr
  \code{install_package.R} \tab student installer; finds the tar.gz, installs deps, then the package \cr
  \code{A04_Regional_Climate_Narratives_v01.Rmd} \tab activity handout; knitting it builds the zip AND the HTML \cr
  \code{docs/downloads/Regional_Climate_Narratives--Student_Files.zip} \tab flat zip students upload \cr
  \code{docs/Activities/A04_Regional_Climate_Narratives.html} \tab published handout \cr
  \code{~/regional_climate_narratives} \tab folder students create and upload the zip into \cr
  \code{~/Regional_Climate_Narratives_XX} \tab per-state project folder created by \code{initialize_project()} \cr
}

Knitting the handout Rmd does everything: it locates the newest tar.gz
near the Rmd, stages it with \code{install_package.R},
\code{example_workflow.R}, and the package reference, zips them (flat,
no wrapper folder), writes the zip to \code{docs/downloads/}, and
renders the HTML to \code{docs/Activities/}. To release an update:
rebuild the tar.gz (below), drop it next to the Rmd, delete the old
tar.gz, re-knit.
}

\section{Releasing a new version (the safe order)}{
\enumerate{
  \item Edit \code{DESCRIPTION}: bump \code{Version:} (e.g. 0.3.2).
  \item Build. In RStudio with the package as working directory:
        \preformatted{devtools::build(vignettes = FALSE)}
        or from a terminal one level above the package folder:
        \preformatted{R CMD build --no-build-vignettes RegionalClimateNarratives}
  \item Rename the output. R names it from the \code{Package:} field
        (\code{RegionalClimateNarratives_0.3.2.tar.gz}). Rename to the
        distribution style:
        \preformatted{file.rename("RegionalClimateNarratives_0.3.2.tar.gz",
            "Regional_Climate_Narratives_0.3.2.tar.gz")}
  \item Move it next to the handout Rmd and DELETE the previous tar.gz
        so version selection cannot grab a stale file.
  \item Re-knit the handout. Check the Render pane for NOTEs.
}
The startup banner and \code{initialize_project()} both derive their
version from \code{utils::packageVersion()}, so no source edits are
needed for a routine version bump.
}

\section{Caveat: filename version vs DESCRIPTION version}{
R installs whatever the \code{DESCRIPTION} inside the tar.gz declares;
the filename is decoration. A file named
\code{Regional_Climate_Narratives_0.3.1.tar.gz} that contains
\code{Version: 0.3.0} installs v0.3.0. Both tools detect this:
\code{install_package.R} prints a \code{[WARN]} after installing, and
the handout knit prints a NOTE in the Render pane and shows the true
(internal) version in the handout text. If you see either, you renamed
a file instead of rebuilding, or forgot to bump \code{DESCRIPTION}
before building.
}

\section{Caveat: the student zip must be flat}{
Students create \code{~/regional_climate_narratives} themselves and
upload the zip into it; RStudio Server auto-extracts uploads. The zip
therefore contains the four files at its ROOT, with no wrapper folder.
If a wrapper folder sneaks back in, extraction produces a nested
folder, \code{setwd("~/regional_climate_narratives")} no longer finds
the tar.gz, and Step 3 of the handout fails for everyone. The
handout's build chunk zips from inside the staging folder for exactly
this reason; do not "fix" it to zip the folder itself.
}

\section{Caveat: rebuilding FROM a tar.gz (no source checkout)}{
If you only have the tar.gz on the server, you can untar it, edit, and
rebuild; a built tarball contains the full source:
\preformatted{untar("Regional_Climate_Narratives_0.3.1.tar.gz", exdir = ".")
# edit RegionalClimateNarratives/DESCRIPTION and R/ files ...
# then, from the folder CONTAINING RegionalClimateNarratives/:
system("R CMD build --no-build-vignettes RegionalClimateNarratives")}
The extracted \code{DESCRIPTION} contains \code{Packaged:} lines added
by the previous build; leave them, the new build refreshes them. The
\code{man/} pages are hand-written Rd; do NOT run
\code{devtools::document()} on the extracted source, it is not needed
for a rebuild.
}

\section{Caveat: server prerequisites}{
The spatial stack (\pkg{sf}, \pkg{stars}, \pkg{gstat}, \pkg{raster})
needs system libraries on the RStudio Server host: GDAL, GEOS, PROJ,
and udunits2. On Ubuntu/Debian:
\preformatted{sudo apt install libgdal-dev libgeos-dev libproj-dev libudunits2-dev}
If students report \code{install.packages("sf")} failing with compiler
errors, this is almost always the cause. Installing these R packages
once site-wide (as admin, into the system library) saves every student
20+ minutes of compilation.
}

\section{Caveat: NOAA downloads}{
\code{download_stations()} for 50 stations takes 10-30 minutes and
depends on NOAA availability. It is resumable: rerunning skips
completed stations. Warn students not to schedule this for the last
hour before a deadline, and stagger large classes if the server's
outbound bandwidth is limited.
}

\section{Teaching scaffolding: the lecture arc}{
The activity supports a three-move lecture that mirrors what students
do in R:
\enumerate{
  \item \strong{One station, one story.} Start with a single long
        station record near campus. Plot raw daily TMAX: it looks like
        noise. Introduce normals and anomalies as the tools that let a
        signal emerge from seasonal cycle and weather variance. Land
        on: one thermometer can show \emph{that} it is warming, but
        not \emph{where} or \emph{when} it warms fastest.
  \item \strong{Fifty stations, one map.} The jump from time series to
        the interpolated trend map. This is where spatial variation
        becomes visible and the state stops being a single number.
  \item \strong{From map to narrative.} Students interrogate their own
        maps: which regions, which seasons, days or nights, wetter or
        drier; and what would that mean for people, agriculture, fire,
        or snowpack there? The narrative video assignment is the
        deliverable form of this move.
}
Each section below expands one of the concepts this arc depends on.
}

\section{Teaching scaffolding: why long records matter}{
Points worth making explicit in lecture:
\itemize{
  \item \strong{Signal-to-noise.} Interannual variability in annual
        mean TMAX is commonly on the order of 1 degree C; the trend
        being estimated is on the order of 1-2 degrees C per CENTURY.
        Short records cannot separate these. A useful in-class demo:
        fit \code{lm()} to the last 15 years of one station and show
        the trend flips sign depending on the window chosen.
  \item \strong{Why 30-year normals.} The WMO baseline convention
        (1961-1990 here) exists because ~30 years averages over most
        interannual and decadal variability (ENSO, PDO) while staying
        short relative to the forced trend. Discuss the trade-off:
        later baselines (1991-2020) make current anomalies look
        smaller because the reference itself has warmed. This is a
        rich "baselines are choices" discussion, and it is why the
        package reports which baseline period each station used.
  \item \strong{Why 50 stations and completeness screening.}
        \code{select_stations(n = 50)} prefers long, complete records.
        Connect this to survivorship and selection: stations that
        lasted 100 years are disproportionately at airports, water
        works, and universities; that is both why they are usable and
        why their siting deserves scrutiny (next section).
  \item \strong{Missing data are not neutral.} A station missing its
        1930s Dust Bowl summers will bias a computed normal. This
        motivates why some stations get skipped
        ("Cannot compute normals... Skipping") rather than patched.
}
}

\section{Teaching scaffolding: spatial variation of climate change}{
Warming is regionally uneven, and student maps will show it. Patterns
to prime students to look for, with the physical story behind each:
\itemize{
  \item \strong{Nights vs days (TMIN vs TMAX).} Minimum temperatures
        are rising faster than maximums in most regions (boundary
        layer, humidity, cloud, and urbanization effects). Have
        students compare their TMIN and TMAX maps; the asymmetry is
        usually visible and is an excellent "the fingerprint is more
        subtle than 'hotter afternoons'" moment.
  \item \strong{Seasonal asymmetry.} Many mid-latitude states warm
        fastest in winter (snow-albedo feedback, cold-air outbreak
        frequency). The 4-panel seasonal map in Step 14 exists for
        this comparison.
  \item \strong{Coastal vs interior, and elevation.} Marine layers
        damp coastal trends; mountain stations can show amplified
        or lagged signals (snow line, inversions). In California,
        expect Central Valley vs coast contrasts.
  \item \strong{Precipitation is patchier than temperature.}
        Precipitation trends are spatially noisy, often mixed-sign
        within a state, and less statistically robust; that is a
        feature for teaching, not a bug: contrast the coherent
        temperature map with the speckled precipitation map and ask
        why (convective scale, skewed distributions, gauge issues).
  \item \strong{Interpolation is a model.} The heat map is
        interpolated BETWEEN stations; it invents values where no
        thermometer exists, and \code{resolution} changes its look.
        Sparse regions (deserts, mountains) are where the map is least
        trustworthy, which students can see by plotting station
        locations over the surface.
}
}

\section{Teaching scaffolding: narratives about poorly located stations}{
Station-quality critiques are the most common skeptical narrative
students will have encountered, so address them head-on:
\itemize{
  \item \strong{Real siting problems exist.} Stations near parking
        lots, rooftops, or AC exhausts; stations that moved; changes
        from afternoon to morning observation time (time-of-observation
        bias); instrument transitions (liquid-in-glass to MMTS).
        Photograph-based siting surveys made this a public argument in
        the 2000s.
  \item \strong{The honest question is not "are some stations bad" but
        "does it bias the NETWORK trend".} Comparisons of well-sited vs
        poorly-sited subsets, and against the purpose-built US Climate
        Reference Network (USCRN, 2005-), find essentially the same
        national trend; homogenization algorithms detect breakpoints by
        comparing each station to its neighbors.
  \item \strong{Urban heat islands are real AND accounted for.} UHI is
        a genuine local effect (great for a lab on its own) but
        rural-only subsets still show the warming trend; UHI cannot
        explain ocean warming, and adjustments in the US NET DOWNWARD
        on balance, the opposite of the "adjusted to create warming"
        narrative.
  \item \strong{Turn it into method, not authority.} Have students find
        the most anomalous station on their own map, look up its
        metadata and location on the NOAA station page or satellite
        imagery, and argue whether to trust, flag, or exclude it, then
        show the map barely changes with one station removed. The
        lesson: single-station skepticism is healthy; network
        conclusions are robust to it.
}
}

\section{Teaching scaffolding: types of data available}{
Situate what this package uses among the alternatives, so students
know the menu:
\itemize{
  \item \strong{GHCN-Daily} (what this package downloads): quality-
        controlled daily station observations; the elements used here
        are TMAX, TMIN, PRCP; the archive also carries SNOW, SNWD, and
        dozens of rarer elements. Strength: real thermometers, daily
        resolution, century-long records. Weakness: gaps, moves,
        uneven spatial coverage.
  \item \strong{GHCN-Monthly / homogenized products}: monthly means
        with breakpoint adjustments; the basis of most global
        temperature indices (NOAAGlobalTemp, GISTEMP, HadCRUT,
        Berkeley Earth).
  \item \strong{Climate normals products}: NOAA publishes official
        1991-2020 (and legacy 1981-2010) U.S. normals; contrast with
        the normals students compute themselves and with the 1961-1990
        baseline used here.
  \item \strong{Gridded observational products}: PRISM, NClimGrid,
        Daymet interpolate stations onto grids with elevation-aware
        methods; convenient and complete, but they inherit and hide
        the station issues students just learned to see. This
        activity's homemade interpolation is a transparent, simplified
        version of what those products do.
  \item \strong{Reanalyses} (ERA5, etc.): weather models constrained
        by observations; physically complete fields everywhere, but
        model-dependent, and trends require care.
  \item \strong{Reference networks}: USCRN as the pristine-siting
        benchmark; short record (2005-) but ideal for the siting
        discussion above.
}
A good synthesis question: "Why did we use messy old stations instead
of a clean modern gridded product?" Because the mess IS the curriculum:
normals, anomalies, gaps, siting, and interpolation are all invisible
in a pre-gridded file.
}

\section{Teaching scaffolding: discussion prompts and misconceptions}{
Prompts that map directly onto student output:
\enumerate{
  \item Which part of your state changed fastest, and who or what
        lives there? (bridge to narrative)
  \item Your TMIN map vs your TMAX map: what does the difference imply
        for heat waves, energy demand, growing season, snowpack?
  \item Find your least-trustworthy map region using the station
        locations. How would you communicate that uncertainty in a
        video without undermining the robust parts?
  \item Two students, two baselines: if one class member used a
        1971-2000 baseline station, are their anomalies comparable to
        a 1961-1990 station's? Why do trends survive baseline choice
        better than anomalies do?
}
Misconceptions to pre-empt:
\itemize{
  \item Weather vs climate: one cold winter on the map's timeline does
        not bend a century trend.
  \item Anomaly vs absolute: a +1.5 C/century trend does not mean the
        state is 1.5 C hotter than the map's neighbor state; anomalies
        remove geography on purpose.
  \item "The data were adjusted, so they're cooked": see the siting
        section; adjustments are documented, neighbor-based, and in
        the U.S. reduce the raw trend.
  \item Interpolated color between stations is evidence: it is an
        estimate; the dots are the evidence.
}
}

\section{Publishing checklist}{
\enumerate{
  \item Tar.gz version, banner version, and handout version all agree
        (knit with no NOTE in the Render pane).
  \item \code{docs/downloads/Regional_Climate_Narratives--Student_Files.zip}
        contains exactly: the tar.gz, \code{install_package.R},
        \code{example_workflow.R}, the package reference; all at root.
  \item Download link works from the published page
        (\code{../downloads/} relative to \code{docs/Activities/}).
  \item Fresh-account test: create \code{regional_climate_narratives},
        upload zip, \code{source("install_package.R")}, confirm the
        banner shows the new version.
}
}

\author{Marc Los Huertos}
\seealso{
  \code{\link{RegionalClimateNarratives-package}},
  \code{\link{check_dependencies}},
  \code{\link{initialize_project}},
  \code{\link{select_stations}},
  \code{\link{create_heatmap}}
}
\keyword{documentation}
