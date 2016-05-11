//------------------------------------------------------------------------------
// <copyright>
//     Copyright (c) Microsoft Corporation. All Rights Reserved.
// </copyright>
//------------------------------------------------------------------------------

using System;
using System.Configuration;

namespace TollApp
{
    internal class Environment
    {
        internal static readonly string EventHubConnectionString = ConfigurationManager.AppSettings["Microsoft.ServiceBus.ConnectionString"];
        internal static readonly string DeviceKey = ConfigurationManager.AppSettings["DeviceKey"];
        internal static readonly string IotHubUri = ConfigurationManager.AppSettings["IotHubUri"];
        
        internal const string EntryEventHubPath = "entry";
        internal const string ExitEventHubPath = "Exit";
        
        
        public static void SetupEventHubs()
        {
            //Console.WriteLine("Create 'Entry' Event Hub");
            //EventHubHelper.CreateEventHubIfNotExists(
            //        EventHubConnectionString,
            //        EntryEventHubPath);

            //Console.WriteLine("Create 'Exit' Event Hub");
            //EventHubHelper.CreateEventHubIfNotExists(
            //        EventHubConnectionString,
            //        ExitEventHubPath);
        }

        public static void Cleanup()
        {
            EventHubHelper.DeleteAllEventHubs(EventHubConnectionString);
        }

        internal static void Setup()
        {
            //SetupEventHubs();
        }
    }
}
