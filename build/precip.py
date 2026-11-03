#!/usr/bin/env python3
"""Statistics shared by the rain and snow sheet generators.

Everything in here exists because of one diagnosis, which two independent
research passes over the overlay reached separately: the sheets did not look
wrong because the individual drops and flakes were drawn badly. They looked
wrong because the POPULATION was wrong. Real precipitation is a very large
number of individually faint elements whose size, brightness and length have a
wide, depth-correlated spread, placed with no spacing rule at all. The sheets
drew a few hundred near-identical elements on a tidy grid, with a small caste
of deliberately bright ones.

Four things follow, and this module is the four of them:

1. Placement is independent uniform, not a jittered grid.

   A homogeneous 3D Poisson field stays Poisson in its projected centres, so
   real snow contains stochastic coincidences: two flakes nearly touching, a
   small knot of four, a conspicuous hole next to it. A jittered grid gives
   every element its own cell and so deletes exactly those events. That is
   what made the snow read as a starfield - not the flake drawing, the lattice
   it was drawn on. The old docstring defended the grid on the grounds that
   uniform placement "reliably leaves bald patches and clumps". It does, and
   that is the point.

2. Sizes come from a power law, not a uniform range.

   For a field of fixed physical size at depth z, apparent size s goes as 1/z,
   and a depth shell holds particles in proportion to z^2 dz. Substituting
   gives p(s) proportional to s^-4. Mixing real size variation in flattens it
   somewhat, so EXP_SIZE below is 3.0-3.3 rather than 4. Either way the shape
   is the thing: overwhelmingly tiny elements, a thin tail of large close ones.
   A uniform range makes every element roughly the same size, which is the
   other half of the starfield.

3. Brightness is lognormal, and there is no bright caste.

   The sheets used to take a uniform alpha and then multiply one element in
   twelve (rain) or one in ten (snow) by about 1.9. Those sparse high-energy
   elements are precisely the landmarks the eye re-identifies when the sheet
   tiles, so the caste was actively buying the repeat it was meant to disguise
   with variety. A continuous lognormal gives a wider true spread with no
   memorable outliers: at sigma 0.6 the 95th percentile is already 2.7x the
   median, more than the caste bought, without any element being special.

4. Blowing snow is spatially intermittent, via a log-Gaussian Cox process.

   Ordinary precipitation is uniform Poisson. Blowing snow under a turbulent
   wind is not: measured concentrations vary strongly in space. cox_field
   modulates the placement intensity with a smooth periodic Gaussian field so
   a gale has patches of denser and thinner snow, which is also one more thing
   for the eye to follow instead of the tile edge. Kept moderate: a very dense
   unique patch is itself a landmark.
"""
import numpy as np

__all__ = ["power_law", "lognormal", "cox_field", "poisson_centres", "stamp"]


def power_law(rng, n, lo, hi, exponent):
    """Sample n values from p(s) proportional to s^-exponent on [lo, hi].

    Inverse-CDF, so it is exact and costs one uniform per sample. The integral
    of s^-k is s^(1-k)/(1-k), which inverts in closed form for any k != 1.
    """
    k = float(exponent)
    if abs(k - 1.0) < 1e-9:                    # the log case, for completeness
        return lo * (hi / lo) ** rng.random(n)
    a, b = lo ** (1.0 - k), hi ** (1.0 - k)
    return (a + rng.random(n) * (b - a)) ** (1.0 / (1.0 - k))


def lognormal(rng, n, median, sigma, lo, hi):
    """Sample n values from a lognormal with the given median, clipped.

    Parameterised by the median rather than the mean because the median is the
    one that survives the clip: exp(mu) is the 50th percentile whatever sigma
    is, so widening the spread does not quietly brighten the sheet. The mean is
    median*exp(sigma^2/2) before clipping, which is what the callers' numbers
    were solved against to hold the sheets at the brightness they had.
    """
    return np.clip(median * np.exp(sigma * rng.standard_normal(n)), lo, hi)


def cox_field(rng, size, sigma, corr_along, corr_across, angle=0.0):
    """A smooth, strictly periodic intensity field with mean 1.

    exp(g - sigma^2/2) for a zero-mean Gaussian field g, which is the intensity
    of a log-Gaussian Cox process. Built in the Fourier domain and brought back
    with an inverse FFT, which is what makes it exactly periodic: the sheet has
    to tile, so a modulation with a visible edge would be worse than no
    modulation at all.

    corr_along and corr_across are correlation lengths in pixels, measured
    along and across `angle` (radians, from straight down, matching the flake
    rasteriser's convention). Blowing snow streaks out along the wind, so the
    two are deliberately not equal.
    """
    f = np.fft.fftfreq(size) * size            # cycles across the sheet
    fy, fx = np.meshgrid(f, f, indexing="ij")

    ca, sa = np.cos(angle), np.sin(angle)
    u = fx * sa + fy * ca                      # frequency along the wind
    v = fx * ca - fy * sa                      # ... and across it

    # A Gaussian correlation function transforms to a Gaussian in frequency.
    # The amplitude is its square root because the power spectrum is the
    # transform of the correlation, and we are building a field, not a power.
    amp = np.exp(-0.5 * ((np.pi * u * corr_along / size) ** 2
                         + (np.pi * v * corr_across / size) ** 2))

    spec = (rng.standard_normal((size, size))
            + 1j * rng.standard_normal((size, size))) * amp
    g = np.fft.ifft2(spec).real
    sd = g.std()
    if sd > 0:
        g = g / sd * sigma
    return np.exp(g - sigma * sigma / 2.0)


def poisson_centres(rng, n, size, intensity=None):
    """n element centres, independent and uniform over the size*size torus.

    No spacing rule, no grid, no exclusion radius: close pairs and holes are
    what a real precipitation field looks like and what makes it stop reading
    as a pattern. Technically binomial rather than Poisson because n is fixed,
    which for a 512 sheet is a difference of a few percent in the count
    variance of a large window and nothing at all in a small one.

    With `intensity`, a size*size array of relative weights (from cox_field),
    centres are drawn by rejection so denser regions get proportionally more.
    """
    if intensity is None:
        return (rng.integers(0, size, n), rng.integers(0, size, n))

    peak = float(intensity.max())
    ys, xs = [], []
    while len(ys) < n:
        batch = max(n - len(ys), 64) * 2
        cy = rng.integers(0, size, batch)
        cx = rng.integers(0, size, batch)
        keep = rng.random(batch) * peak < intensity[cy, cx]
        ys.extend(cy[keep][: n - len(ys)].tolist())
        xs.extend(cx[keep][: n - len(xs)].tolist())
    return np.array(ys), np.array(xs)


def stamp(sheet, element, cy, cx):
    """Composite one element onto the sheet, wrapping in both axes.

    `maximum` rather than a sum: overlapping drops are the same water seen
    twice, not twice as much light, and adding them blows a clipped white blob
    wherever two elements happen to cross. Wrapping is what makes the sheet
    tile - an element that runs off the right edge comes back on the left, so
    there is no border region where nothing is ever drawn.
    """
    size = sheet.shape[0]
    eh, ew = element.shape
    ys = (int(cy) + np.arange(eh)) % size
    xs = (int(cx) + np.arange(ew)) % size
    idx = np.ix_(ys, xs)
    sheet[idx] = np.maximum(sheet[idx], element)
