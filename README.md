# Convert XML files from Tanzil.net to SQLite import files

This application is used to convert XML files [downloaded from Tanzil.net](https://tanzil.net/download/) into SQLite import files.

It also applies the following in the process of converting:

- Adds Bismillah with Aya #0 to all Surahs (except to Al-Fatiha and at-Tawbah)
- Each row will have surahNumber, ayaNumber and text (Primary key is composite surahNumber, ayaNumber)

The reason we don't just use SQL (MySQL Dumps) files from Tanzil directly, is because all of them include Bismillah in the first Aya's text, searching and replacing it risks some unwanted changes.

# OS Requirements

- macOS 13 Ventura or later

# License

The code and application itself are licensed under Apache License 2.0

But XML files downloaded from Tanzil have their own terms and condition.

Terms are mentioned below but please read about additional conditions [in this page](https://tanzil.net/download/)

**Terms of Use from Tanzil website:**

Permission is granted to copy and distribute verbatim copies of the Quran text provided here, but changing the text is not allowed.

The text can be used in any website or application, provided that its source [(Tanzil Project)](https://tanzil.net/download/) is clearly indicated, and a link is made to [tanzil.net](https://tanzil.net) to enable users to keep track of changes. 

