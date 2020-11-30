import setuptools

with open("README.md", "r") as fh:
    long_description = fh.read()

def main():
    setuptools.setup(name="hoap",
          version="0.1",
          description="A Python/Hy module to with pointer-like structures and memory heap.",
          long_description=long_description,
          long_description_content_type="text/markdown",
          author="Atell Krasnopolski",
          url="https://github.com/gojakuch/hoap",
          packages=setuptools.find_packages(),
          license="MIT License",
          classifiers=[
            "Programming Language :: Python :: 3",
            "License :: OSI Approved :: MIT License",
            "Operating System :: OS Independent",
          ],
          ext_modules=[setuptools.Extension("hoap", ["hoap.c"])])

if __name__ == "__main__":
    main()
