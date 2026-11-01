# Turkmen-Lights-vs-GDP 🇹🇲

**[Look at it here →](https://01a18ead-54e7-4ce7-5fe2-ab2996fef91f.share.connect.posit.cloud/)**

Turkmenistan reports steady growth of about 6% a year, every year. This scrollytelling piece checks that claim against satellite images of the country's lights at night. Using VIIRS nighttime-lights data for 2014–2021 and a published light-to-GDP elasticity, official GDP grows by about 53% while the lights suggest the economy shrank by about 3%, a gap of 56 points. An independent IMF reconstruction of Turkmenistan's GDP also finds a roughly flat economy, and among five comparison countries, Turkmenistan is the only one whose lights fell. Built in R and Quarto with Closeread, and published on Posit Connect Cloud.

## Limitations

1. **The elasticity is uncertain**, but the result points the same way for any positive β. Turkmenistan's light fell about 19%, which gives −1% at β = 0.04 and −8% at β = 0.40, and a larger β makes the gap wider.
2. **The country comparison is small.** Five countries are too few for a formal test. Uzbekistan comes close because it reports fast growth, so the clearer contrast is that only Turkmenistan's light fell.
3. **Gas flares are about 28% of the light** in 2019, and the main series isn't flare-masked yet.
