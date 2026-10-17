// SPDX-License-Identifier: GPL-2.0-or-later
#include "IconIdentity.h"
#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>

class IconIdentityTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void namedIconsCompareByNameRatherThanPixels()
    {
        QTemporaryDir temporary;
        QVERIFY(temporary.isValid());
        QDir root(temporary.path());
        QVERIFY(root.mkpath("fixture/32x32/apps"));
        QFile index(root.filePath("fixture/index.theme"));
        QVERIFY(index.open(QIODevice::WriteOnly));
        index.write("[Icon Theme]\nName=Fixture\nDirectories=32x32/apps\n\n[32x32/apps]\nSize=32\nType=Fixed\nContext=Applications\n");
        index.close();
        QPixmap image(32, 32);
        image.fill(Qt::red);
        QVERIFY(image.save(root.filePath("fixture/32x32/apps/work.png")));
        QVERIFY(image.save(root.filePath("fixture/32x32/apps/personal.png")));
        const auto searchPaths = QIcon::themeSearchPaths();
        const auto theme = QIcon::themeName();
        QIcon::setThemeSearchPaths({temporary.path()});
        QIcon::setThemeName("fixture");
        const auto work = QIcon::fromTheme("work");
        const auto personal = QIcon::fromTheme("personal");
        IconIdentity provider;
        const auto workName = provider.identity(work);
        const auto personalName = provider.identity(personal);
        QIcon::setThemeSearchPaths(searchPaths);
        QIcon::setThemeName(theme);
        QCOMPARE(workName, QStringLiteral("work"));
        QCOMPARE(personalName, QStringLiteral("personal"));
        QCOMPARE(provider.identity(QStringLiteral("work")), QStringLiteral("work"));
    }

    void missingAndUnnamedIconsHaveNoName()
    {
        IconIdentity provider;
        QPixmap image(32, 32);
        image.fill(Qt::red);
        QVERIFY(provider.identity(QVariant()).isEmpty());
        QVERIFY(provider.identity(QIcon()).isEmpty());
        QVERIFY(provider.identity(QIcon(image)).isEmpty());
    }
};

QTEST_MAIN(IconIdentityTest)
#include "test_icon_identity.moc"
