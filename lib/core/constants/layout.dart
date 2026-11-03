/// The artifact's `.ag` and `.st` grids declare `grid-design-columns`, which
/// is not a valid CSS property, so a browser renders them as one single
/// column (which also makes the editor's tool panels overflow the screen).
///
/// `false` (default) gives the multi-column layout the stylesheet was
/// evidently written for (4 / 6 / 3 columns). Set it to `true` to reproduce
/// the single column a browser actually shows.
const bool kMatchRenderedGrid = false;

/// Maximum width of the "phone" column.
const double kPhoneMaxWidth = 430;
