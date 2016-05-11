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
using Newtonsoft.Json;
using Microsoft.Azure.Devices.Client;
using System.Threading.Tasks;

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

            //SendData(Environment.EventHubConnectionString, Environment.EntryEventHubPath, Environment.ExitEventHubPath);

            SendDeviceToCloudMessagesAsync();
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

        private static void SendDeviceToCloudMessagesAsync()
        {
            Console.WriteLine("Simulated device\n");
            DeviceClient deviceClient = DeviceClient.Create(Environment.IotHubUri, new DeviceAuthenticationWithRegistrySymmetricKey("myFirstDevice", Environment.DeviceKey));

            double avgWindSpeed = 10; // m/s
            Random rand = new Random();

            var entryEventHub = EventHubClient.CreateFromConnectionString(Environment.EventHubConnectionString, Environment.EntryEventHubPath);

            while (true)
            {
                double currentWindSpeed = avgWindSpeed + rand.NextDouble() * 4 - 2;

                var telemetryDataPoint = new
                {
                    DeviceId = "myFirstDevice",
                    EventTime = DateTime.UtcNow,
                    WindSpeed = currentWindSpeed
                };
                var messageString = JsonConvert.SerializeObject(telemetryDataPoint);

                entryEventHub.Send(
                         new EventData(Encoding.UTF8.GetBytes(messageString))
                         {
                             PartitionKey = telemetryDataPoint.DeviceId.ToString(CultureInfo.InvariantCulture)
                         });


                //var message = new Message(Encoding.ASCII.GetBytes(messageString));
                //await deviceClient.SendEventAsync(message);
                
                Console.WriteLine("{0} > Sending message: {1}", DateTime.Now, messageString);

                Task.Delay(1000).Wait();
            }
        }
    }
}
