﻿namespace ExampleApp.Web.Controllers
{
    using System.Configuration;
    using System.Web.Mvc;
    using Microsoft.ServiceBus;
    using Models;

    /// <summary>
    /// Defines supported actions for the Homepage.
    /// </summary>
    public class HomeController : Controller
    {
        /// <summary>
        /// Handles the default HTTP GET /.
        /// </summary>
        /// <returns>Returns the default Homepage view.</returns>
        public
        ActionResult
        Index()
        {
            var serviceBusNamespaceManager = NamespaceManager.CreateFromConnectionString(
                ConfigurationManager.AppSettings["Microsoft.ServiceBus.ConnectionString"]
            );

            this.ViewBag.Title                  = "Home Page";
            this.ViewBag.ServiceBusNamespace    = serviceBusNamespaceManager.Address.ToString();

            var defaultValues = new CreateQueueCommandModel {
                MaxQueueSizeMegabytes                      = 1024,
                StorageCapacityScaleOutThresholdPercentage = 1
            };

            return this.View(defaultValues);
        }

        /// <summary>
        /// Handles the HTTP GET /QueueInformation.
        /// </summary>
        /// <param name="queueName">Specifies the name of the queue to get information for.</param>
        /// <returns>Returns a partial view containing the queues information.</returns>
        public
        ActionResult
        QueueInformation(
            string queueName)
        {
            this.ViewBag.QueueName = queueName;

            return this.PartialView("QueueInformation");
        }

        /// <summary>
        /// Handles the HTTP GET /ManageQueue request.
        /// </summary>
        /// <param name="queueName">Specifies the name of the queue.</param>
        /// <returns>Returns a partial view of the queue management UI.</returns>
        public
        ActionResult
        ManageQueue(
            string queueName)
        {
            this.ViewBag.QueueName = queueName;

            return this.PartialView("ManageQueue");
        }
    }
}