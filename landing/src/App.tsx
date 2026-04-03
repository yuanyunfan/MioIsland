import { I18nProvider } from "./lib/i18n"
import Navbar from "./components/Navbar"
import Hero from "./components/Hero"
import NotchDemo from "./components/NotchDemo"
import Features from "./components/Features"
import HowItWorks from "./components/HowItWorks"
import OpenSource from "./components/OpenSource"
import Footer from "./components/Footer"

function App() {
  return (
    <I18nProvider>
      <Navbar />
      <Hero />
      <NotchDemo />
      <Features />
      <HowItWorks />
      <OpenSource />
      <Footer />
    </I18nProvider>
  )
}

export default App
