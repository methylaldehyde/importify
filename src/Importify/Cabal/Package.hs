-- | Utility functions to work with 'GenericPackageDescription' and
-- other miscellaneous stuff in .cabal files.

module Importify.Cabal.Package
       ( libraryIncludeDirs
       , packageDependencies
       , readCabal
       , withLibrary
       ) where

import           Universum                             hiding (fromString)

import           Distribution.Package                  (Dependency (..), PackageName (..))
import           Distribution.PackageDescription       (Benchmark (benchmarkBuildInfo),
                                                        BuildInfo (..), CondTree,
                                                        Executable (..),
                                                        GenericPackageDescription (..),
                                                        Library (..),
                                                        TestSuite (testBuildInfo),
                                                        condTreeData)
import           Distribution.PackageDescription.Parse (readPackageDescription)
import           Distribution.Verbosity                (normal)


readCabal :: FilePath -> IO GenericPackageDescription
readCabal = readPackageDescription normal

-- | Perform given action with package library 'BuilInfo'
-- if 'Library' is present. We care only about library exposed modules
-- because only they can be imported outside that package. Action
-- returns 'Monoid'al values so if there's no 'Library' user gets
-- @pure mempty@. In code this is used to collect list of modules.
withLibrary :: (Applicative f, Monoid m)
            => GenericPackageDescription
            -> (Library -> f m)
            -> f m
withLibrary GenericPackageDescription{..} action =
    maybe (pure mempty)
          (action . condTreeData)
          condLibrary

-- | Returns all include directories for 'Library'.
libraryIncludeDirs :: Library -> [FilePath]
libraryIncludeDirs = includeDirs . libBuildInfo

dependencyName :: Dependency -> String
dependencyName (Dependency PackageName{..} _) = unPackageName

-- | Retrieve list of unique names for all package dependencies inside
-- library, all executables, all test suites and all benchmarks for a
-- given package.
--
-- TODO: what about version bounds?
packageDependencies :: GenericPackageDescription -> [String]
packageDependencies = ordNub
                    . concatMap (map dependencyName . targetBuildDepends)
                    . allBuildInfos

allBuildInfos :: GenericPackageDescription -> [BuildInfo]
allBuildInfos GenericPackageDescription{..} = concat
    [ maybe [] (one . libBuildInfo . condTreeData) condLibrary
    , collectBuildInfos          buildInfo condExecutables
    , collectBuildInfos      testBuildInfo condTestSuites
    , collectBuildInfos benchmarkBuildInfo condBenchmarks
    ]

collectBuildInfos :: (t -> BuildInfo) -> [(String, CondTree v c t)] -> [BuildInfo]
collectBuildInfos extractor = map (extractor . condTreeData . snd)

-- This function works but isn't used anywhere
{-
findModuleBuildInfo :: String -> GenericPackageDescription -> Maybe BuildInfo
findModuleBuildInfo modNameStr pkg@GenericPackageDescription{..} =
    lookupExecutable <|> lookupExposedModules <|> lookupOtherModules
  where
    modName = fromString modNameStr
    lookupExecutable = asum $ do
        (_name, condExecutable) <- condExecutables
        let exec = condTreeData condExecutable
        if (modulePath exec) == (toFilePath modName ++ ".hs") then
            pure $ Just (buildInfo exec)
        else
            pure Nothing
    lookupExposedModules = case condLibrary of
        Just condTree ->
            if elem modName (exposedModules lib) then Just (libBuildInfo lib) else Nothing
            where lib = condTreeData condTree
        Nothing -> Nothing
    lookupOtherModules = find (elem modName . otherModules) $ getBuildInfos pkg
-}
