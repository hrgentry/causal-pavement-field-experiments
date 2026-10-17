Supplementary Data S1. Variability and denominators.

observed_mean_sd.csv supplies descriptive SDs and counts for author-computed record/physical-pair/project averages. A single-date SD is unavailable, not zero. Shared visits, sections and campaigns are not independent allocations. conditional_score_mean_sd.csv gives descriptive spread across overlapping conditional deletion scores; it supplies no independent-unit SE. posterior_target_sd.csv labels posterior SD separately from observed-data SD, and retained draws separately from experimental sample size.

The endpoint supplied by LTPP is itself the larger half-lane recorded mean. Within-survey point-level SD cannot be reconstructed from these frozen aggregate records; no instrument-dispersion or physical calibration claim is made. Do not infer SD from the reported credible interval.

The ordinary means in the paper remain unchanged. Examples: Manitoba four-pair/13-campaign mean rounds to1.365 mm; SPS10 project-equal absolute contrasts round to0.250 and0.655 mm. All supplementary values derive from committed fixed records/draws, with no sampling or model refit.

Field dictionary and averaging rules

Every descriptive SD and posterior SD uses the n-1 denominator (sample SD); SD is not an SE. SD is blank for n=1, not zero.

observed_mean_sd.csv: n counts the stated aggregation units. Manitoba differences are intensive-minus-minimum preparation; each pair history has13 campaigns. The all-record n=52 includes overlapping pairs/campaigns, while the four-history-means row has n=4 physical pairs. SPS10 contrasts involve two physical sections per project (12 across six projects); the full case set has18 sections. Project-equal absolute differences average the within-project date means equally, rather than pooling visits.

sps10_score_mean_sd.csv: near5 deletes the selected near-five complete date in each of five projects; lopo means leave-one-project-out and scores23 complete-triplet dates across six projects. CRPS is first averaged across complete dates within each project, then equally across projects. Its SD is across those five/six project-level means, not pooled visit scores or an independent-unit SE.

posterior_target_sd.csv: for SPS10 keys, column0=F-H (foamed WMA minus HMA) and column1=C-H (chemical WMA minus HMA). For Manitoba __delta keys, column0=preparation (intensive minus minimum), column1=material (recycled minus virgin), column2=thickness (upper minus lower documented group). Values are inmm.

SPS keys encode model/prior, a fixed lambda completion, and target. lambda0/0.5/1 are unidentified repeatability assumptions, not estimated fractions. new6 is the equal mean of location-distribution means within six existing projects; new4 uses the four projects bracketing five years; existing4 retains their observed-section offsets; expected_bracket_operator is the expected recorded linear interpolation functional E(WY). They are distribution/parameter means, not a predictive depth at one new physical section or identified causal effects.

Manitoba __delta targets standardize across the original13 campaign ages and four sections per factor level. A rounded-likelihood model label changes the likelihood; these delta draws still describe the underlying unrounded recorded-scale mean. They are distinct from the separately computed expected integer record. Retained draws (8000) describe Monte Carlo storage, not experimental replication.
