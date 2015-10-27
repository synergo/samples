//------------------------------------------------------------------------------
// <copyright>
//     Copyright (c) Microsoft Corporation. All Rights Reserved.
// </copyright>
//------------------------------------------------------------------------------

using System;
using System.Globalization;
using System.Text;
using System.Threading;
using Microsoft.ServiceBus.Messaging;

namespace TollApp
{
    public class Program
    {
        private static Timer timer;

        public static void Main()
        {
            if (string.IsNullOrEmpty(Environment.EventHubConnectionString))
            {
                Console.WriteLine("Please specify Service Bus connection string in the App.config file");
                return;
            }

            while (true)
            {
                Console.WriteLine("1. Setup input sources");
                Console.WriteLine("2. Send toll data to Event Hub");
                Console.WriteLine("3. Cleanup");
                Console.WriteLine("4. Exit");

                Console.WriteLine("\nChoose action 1-4:");

                var action = Console.ReadLine();

                switch (action)
                {
                    case "1":
                        Environment.Setup();
                        break;
                    case "2":
                        SendData(Environment.EventHubConnectionString, Environment.EntryEventHubPath, Environment.ExitEventHubPath);
                        break;
                    case "3":
                        Environment.Cleanup();
                        break;
                    case "4":
                        return;
                }

                Console.WriteLine("\n\n");
            }
        }

        public static void SendData(string serviceBusConnectionString, string entryHubName, string exitHubName)
        {
            var entryEventHub = EventHubClient.CreateFromConnectionString(serviceBusConnectionString, entryHubName);
            var exitEventHub = EventHubClient.CreateFromConnectionString(serviceBusConnectionString, exitHubName);
           
            var timerInterval = TimeSpan.FromSeconds(1);
            var generator = TollDataGenerator.Generator();

            TimerCallback timerCallback = state =>
            {
                var startTime = DateTime.UtcNow;
                generator.Next(startTime, timerInterval, 5);

                foreach (var e in generator.GetEvents(startTime))
                {
                    if (e is EntryEvent)
                    {
                        entryEventHub.Send(
                           new EventData(Encoding.UTF8.GetBytes(e.Format()))
                                    {
                                        PartitionKey = e.TollId.ToString(CultureInfo.InvariantCulture)
                                    });
                    }
                    else
                    {
                        exitEventHub.Send(
                           new EventData(Encoding.UTF8.GetBytes(e.Format()))
                           {
                               PartitionKey = e.TollId.ToString(CultureInfo.InvariantCulture)
                           });
                    }
                }

                timer.Change((int)timerInterval.TotalMilliseconds, Timeout.Infinite);
            };

            timer = new Timer(timerCallback, null, Timeout.Infinite, Timeout.Infinite);
            timer.Change(0, Timeout.Infinite);

            Console.WriteLine("Sending event hub data... Press Ctrl+c to stop.");

            var exitEvent = new ManualResetEvent(false);
            Console.CancelKeyPress += (sender, eventArgs) =>
            {
                Console.WriteLine("Stopping...");
                eventArgs.Cancel = true;
                exitEvent.Set();
            };

            exitEvent.WaitOne();
            Console.WriteLine("Shutting down all resources...");
            timer.Change(Timeout.Infinite, Timeout.Infinite);
            Thread.Sleep(timerInterval);
            timer.Dispose();
            entryEventHub.Close();
            exitEventHub.Close();
            Console.WriteLine("Stopped.");
        }
    }
}
