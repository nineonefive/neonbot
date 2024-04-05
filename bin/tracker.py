import argparse
from seleniumbase import Driver
from seleniumbase import page_actions

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    args = parser.parse_args()
    url = args.url

    driver = Driver(headless=True, uc=True)
    driver.get(url)
    page_actions.wait_for_text(driver, "Fortnite", "span")
    print(driver.get_page_source())
    driver.quit()
