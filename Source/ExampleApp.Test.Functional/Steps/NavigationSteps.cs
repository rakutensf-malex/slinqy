﻿using ExampleApp.Test.Functional.Models;
using ExampleApp.Test.Functional.Models.ExampleAppPages;
using TechTalk.SpecFlow;

namespace ExampleApp.Test.Functional.Steps
{
    [Binding]
    public class NavigationSteps
    {
        private readonly WebBrowser _webBrowser;

        public 
        NavigationSteps(
            WebBrowser webBrowser)
        {
            _webBrowser = webBrowser;
        }

        [Given]
        public void GivenINavigateToTheHomePage()
        {
            // Attempt to navigate to the Home page.
            _webBrowser.NavigateTo<HomePage>(); 
        }
    }
}