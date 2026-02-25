package bech32

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/mercuryd/tests/integration"
	"github.com/huyCuong73/mercury/tests/integration/precompiles/bech32"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestBech32PrecompileTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.Bech32PrecompileApp](integration.CreateEvmd, "evm.Bech32PrecompileApp")
	s := bech32.NewPrecompileTestSuite(create)
	suite.Run(t, s)
}
