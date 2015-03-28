using System;
using System.Collections.Generic;
using System.Linq;
using System.Reactive.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Configuration;

namespace SecurityBadgeScan
{
    class Program
    {
        static void Main(string[] args)
        {
            var config = new EventHubConfig();
                  
            
            // Uncomment for picking from Configuration 
            config.ConnectionString = ConfigurationManager.AppSettings["EventHubConnectionString"];
            config.EventHubName = ConfigurationManager.AppSettings["EventHubName"];
                        
            //To push 1 event per second
            var eventHubevents = Observable.Interval(TimeSpan.FromSeconds(1)).Select(i => Badge.Generate());

            //To send Data to EventHub as JSON
            var eventHubDis = eventHubevents.Subscribe(new EventHubObserver(config));
                                
            Console.ReadLine();
            eventHubDis.Dispose();
                   
	
        }
    }
}
