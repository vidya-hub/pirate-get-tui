# Homebrew formula for pirate-get
# Install with: brew install --build-from-source pirate-get.rb
# Or add to a tap and install normally

class PirateGet < Formula
  include Language::Python::Virtualenv

  desc "Command-line torrent search tool for The Pirate Bay with TUI"
  homepage "https://github.com/vikstrous/pirate-get"
  url "https://github.com/vikstrous/pirate-get/archive/refs/tags/v0.4.2.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256_HASH"
  license "AGPL-3.0-or-later"
  head "https://github.com/vikstrous/pirate-get.git", branch: "master"

  depends_on "python@3.11"

  resource "colorama" do
    url "https://files.pythonhosted.org/packages/d8/53/6f443c9a4a8358a93a6792e2acffb9d9d5cb0a5cfd8802644b7b1c9a02e4/colorama-0.4.6.tar.gz"
    sha256 "08695f5cb7ed6e0531a20572697297273c47b8cae5a63ffc6d6ed5c201be6e44"
  end

  resource "veryprettytable" do
    url "https://files.pythonhosted.org/packages/source/v/veryprettytable/veryprettytable-0.8.1.tar.gz"
    sha256 "REPLACE_WITH_ACTUAL_SHA256_HASH"
  end

  resource "pyperclip" do
    url "https://files.pythonhosted.org/packages/a7/2c/4c64579f847f5dc3ce1e08c793e2e00a6dc12f5621c40a2e9e8a5f01e4f5/pyperclip-1.8.2.tar.gz"
    sha256 "105254a8b04934f0bc84e9c24eb360a591aaf6535c9def5f29d92af107a9bf57"
  end

  resource "textual" do
    url "https://files.pythonhosted.org/packages/source/t/textual/textual-1.0.0.tar.gz"
    sha256 "REPLACE_WITH_ACTUAL_SHA256_HASH"
  end

  resource "rich" do
    url "https://files.pythonhosted.org/packages/source/r/rich/rich-13.7.0.tar.gz"
    sha256 "REPLACE_WITH_ACTUAL_SHA256_HASH"
  end

  resource "markdown-it-py" do
    url "https://files.pythonhosted.org/packages/source/m/markdown-it-py/markdown_it_py-3.0.0.tar.gz"
    sha256 "REPLACE_WITH_ACTUAL_SHA256_HASH"
  end

  resource "mdurl" do
    url "https://files.pythonhosted.org/packages/source/m/mdurl/mdurl-0.1.2.tar.gz"
    sha256 "bb413d29f5eea38f31dd4754dd7377d4465116fb207585f97bf925588687c1ba"
  end

  resource "pygments" do
    url "https://files.pythonhosted.org/packages/source/p/pygments/pygments-2.17.2.tar.gz"
    sha256 "REPLACE_WITH_ACTUAL_SHA256_HASH"
  end

  def install
    virtualenv_install_with_resources
  end

  test do
    assert_match "pirate-get", shell_output("#{bin}/pirate-get --version")
  end
end
