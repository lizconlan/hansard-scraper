# Hansard Scraper

Scrapes pages from publications.parliament.uk, parses them and stores them in MongoDB. So far the code only deals with Commons Hansard pages.

## Storage Structure

Each day's worth of Hansard is stored as a DailyPart which contains Sections which themselves comprise 
Fragments of individual Paragraphs. (As it turns out, "paragraph" is a slightly misleading term - technically they are (or at least can be) paragraph fragments. More should be done to make the distinction clear (or at least flag paragraphs which should be treated as fragmented). Paragraph fragmentation occurs when a paragraph spans 2 columns.)

Fragments have a number of subtypes allowing them to be addressed generically as Fragments or as Debates, Statements, Questions and Intros, all with their own attribute signatures. By the same token, Paragraphs can also be ContributionParas (Member contributions), NonContributionParas (linking text, etc), ContributionTables (a little misleading perhaps but you get the idea) and Divisions.

## Data Retrieval

Thanks to the flexibility of Mongo, we can pull out Hansard content by Member name, by day, section or column reference. The column reference retrieval isn't 100% accurate as some of the data - notably for tables and divisions - isn't in the source HTML but it's still an interesting example of what can be done.

## Bonus Features

As well as scraping the HTML into the db, there are also rake tasks to manipulate the stored data.

### Search

Running <code>rake index_hansard date=YYYY-MM-DD</code> indexes a day's worth of Hansard using Sunspot to talk to the WebSolr index.

### Kindle

As part of the parsing process, simplified k_html fields are stored at the Fragment level; <code>rake kindle:generate_edition_commons date=YYYY-MM-DD</code> grabs a day's worth, shuffles them into the correct order and does all the fiddly stuff needed to generate a .mobi file in Kindle newspaper format.