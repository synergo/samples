Scenario:
A company just released a product and want to show ads based on what customers are talking about the products and their sentiments around it. They want to leverage real time analytics by tapping into twitter feeds and count the number of tweets on their product and find the average sentiment score.

Pre-Req:
Visual Studio
Azure Subscription
Twitter Account

Running the generator code and setting up the Stream Analytics job is very simple.
This sample contains an event generator which uses Twitter API to get tweet events. Application parses tweets for parameterized keywords (Obama,Skype,XBox,Microsoft, etc.) and uses open source Sentiment140 to add sentiment score to tweet events. To run the sample you will need to first create an EventHub and configure the App.config with its connection string.
You can then create a Stream Analytics Job. Configure the input to point to the EventHub your have created. In the Query Window you can copy and paste the Query below:


SELECT Topic,count(*) AS Count, Avg(SentimentScore) AS AvgSentiment, System.Timestamp AS Insert_Time
FROM TwitterInput TIMESTAMP BY CreatedAt
GROUP BY TumblingWindow(second,5), Topic


In Azure DB, create a SQL Database:

CREATE DATABASE TwitterDemo
GO

Then create a table with the schema below:

USE [TweetCount]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[TweetCount](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[Topic] [nvarchar](128) NULL,
	[Count] [int] NULL,
	[AvgSentiment] [float] NULL,
	[Insert_Time] [datetime2](6) NULL,
 CONSTRAINT [PK_TweetCount] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
)

GO